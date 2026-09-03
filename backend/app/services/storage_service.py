import os
import shutil
from abc import ABC, abstractmethod
from pathlib import Path
from typing import BinaryIO


class BaseStorageService(ABC):
    @abstractmethod
    async def save_file(
        self, grievance_id: str, filename: str, file_data: BinaryIO
    ) -> str:
        """Saves file for a grievance and returns relative storage_path."""
        pass

    @abstractmethod
    async def delete_file(self, storage_path: str) -> None:
        """Deletes file at storage_path if it exists."""
        pass

    @abstractmethod
    def get_absolute_path(self, storage_path: str) -> Path:
        """Resolves relative storage_path to absolute Path on disk."""
        pass


class LocalFileSystemStorage(BaseStorageService):
    def __init__(self, base_dir: str = "storage/grievances"):
        # Resolve storage directory relative to backend project root
        backend_root = Path(__file__).resolve().parent.parent.parent
        self.root_dir = backend_root.parent if (backend_root / "app").exists() and backend_root.name == "backend" else backend_root
        self.base_dir = (self.root_dir / base_dir).resolve()
        self.base_dir.mkdir(parents=True, exist_ok=True)

    async def save_file(
        self, grievance_id: str, filename: str, file_data: BinaryIO
    ) -> str:
        # Strict path traversal checks
        if ".." in grievance_id or "/" in grievance_id or "\\" in grievance_id:
            raise ValueError("Path traversal attempt detected in grievance_id.")
        if ".." in filename or "/" in filename or "\\" in filename:
            raise ValueError("Path traversal attempt detected in filename.")

        target_dir = (self.base_dir / grievance_id / "original").resolve()
        if not str(target_dir).startswith(str(self.base_dir)):
            raise ValueError("Path traversal attempt detected in storage directory.")

        target_dir.mkdir(parents=True, exist_ok=True)
        target_path = (target_dir / filename).resolve()

        if not str(target_path).startswith(str(target_dir)):
            raise ValueError("Path traversal attempt detected in target filename.")

        # Save file contents
        file_data.seek(0)
        with open(target_path, "wb") as f:
            shutil.copyfileobj(file_data, f)

        # Store path relative to project root for portability
        relative_path = target_path.relative_to(self.root_dir).as_posix()
        return relative_path

    async def delete_file(self, storage_path: str) -> None:
        try:
            abs_path = self.get_absolute_path(storage_path)
            if abs_path.exists() and abs_path.is_file():
                abs_path.unlink()
        except Exception:
            pass

    def get_absolute_path(self, storage_path: str) -> Path:
        if ".." in storage_path:
            raise ValueError("Access denied: path traversal attempt in storage_path.")
        clean_path = Path(storage_path)
        abs_path = (self.root_dir / clean_path).resolve()

        if not str(abs_path).startswith(str(self.base_dir)):
            raise ValueError("Access denied: path outside storage directory.")

        return abs_path


class S3CloudStorageService(BaseStorageService):
    """Production S3 / Cloud Object Storage provider abstraction."""
    def __init__(self):
        self.bucket_name = os.getenv("S3_BUCKET_NAME", "janmitra-production-grievances")
        self.region = os.getenv("AWS_REGION", "ap-south-1")
        self.local_fallback = LocalFileSystemStorage()

    async def save_file(self, grievance_id: str, filename: str, file_data: BinaryIO) -> str:
        access_key = os.getenv("AWS_ACCESS_KEY_ID")
        secret_key = os.getenv("AWS_SECRET_ACCESS_KEY")
        if not access_key or not secret_key:
            # Clean fallback to local disk storage if cloud credentials unavailable
            return await self.local_fallback.save_file(grievance_id, filename, file_data)

        try:
            import boto3
            s3 = boto3.client("s3", region_name=self.region, aws_access_key_id=access_key, aws_secret_access_key=secret_key)
            key = f"grievances/{grievance_id}/original/{filename}"
            file_data.seek(0)
            s3.upload_fileobj(file_data, self.bucket_name, key)
            return f"s3://{self.bucket_name}/{key}"
        except Exception:
            return await self.local_fallback.save_file(grievance_id, filename, file_data)

    async def delete_file(self, storage_path: str) -> None:
        if storage_path.startswith("s3://"):
            try:
                import boto3
                parts = storage_path.replace("s3://", "").split("/", 1)
                if len(parts) == 2:
                    s3 = boto3.client("s3")
                    s3.delete_object(Bucket=parts[0], Key=parts[1])
            except Exception:
                pass
        else:
            await self.local_fallback.delete_file(storage_path)

    def get_absolute_path(self, storage_path: str) -> Path:
        return self.local_fallback.get_absolute_path(storage_path)


def get_storage_service() -> BaseStorageService:
    backend = os.getenv("STORAGE_BACKEND", "local").lower()
    if backend == "s3":
        return S3CloudStorageService()
    return LocalFileSystemStorage()
