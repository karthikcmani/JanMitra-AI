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
        # Base directory relative to backend root
        self.base_dir = Path(base_dir).resolve()
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

        # Store path relative to backend root for portability
        relative_path = target_path.relative_to(self.base_dir.parent.parent).as_posix()
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
        root_dir = self.base_dir.parent.parent.resolve()
        abs_path = (root_dir / clean_path).resolve()

        if not str(abs_path).startswith(str(self.base_dir)):
            raise ValueError("Access denied: path outside storage directory.")

        return abs_path
