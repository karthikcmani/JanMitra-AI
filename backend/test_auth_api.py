import asyncio
import time
from httpx import ASGITransport, AsyncClient
from app.main import app


async def test_full_auth_flow():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        print("--- 1. Testing Health Check ---")
        res = await client.get("/api/v1/health")
        assert res.status_code == 200, f"Health check failed: {res.text}"
        print("Health check response:", res.json())

        timestamp = int(time.time())
        test_email = f"test_citizen_{timestamp}@gov.in"
        test_password = "SecurePassword123!"

        print(f"\n--- 2. Testing User Registration ({test_email}) ---")
        reg_payload = {
            "full_name": "Rajesh Kumar",
            "email": test_email,
            "phone": "9876543210",
            "password": test_password,
            "role": "citizen",
        }
        res = await client.post("/api/v1/auth/register", json=reg_payload)
        assert res.status_code == 201, (
            f"Registration failed ({res.status_code}): {res.text}"
        )
        user_data = res.json()["user"]
        assert user_data["email"] == test_email
        assert user_data["full_name"] == "Rajesh Kumar"
        print("Registered User:", user_data)

        print("\n--- 3. Testing Duplicate Email Validation ---")
        res_dup = await client.post("/api/v1/auth/register", json=reg_payload)
        assert res_dup.status_code == 400, (
            f"Expected 400 for duplicate email, got {res_dup.status_code}"
        )
        print("Duplicate Registration Response:", res_dup.json())

        print("\n--- 4. Testing Invalid Password Login ---")
        invalid_login = {"email": test_email, "password": "WrongPassword!"}
        res_inv = await client.post("/api/v1/auth/login", json=invalid_login)
        assert res_inv.status_code == 401, (
            f"Expected 401 for wrong password, got {res_inv.status_code}"
        )
        print("Invalid Password Response:", res_inv.json())

        print("\n--- 5. Testing Valid User Login & JWT Tokens ---")
        valid_login = {"email": test_email, "password": test_password}
        res_login = await client.post("/api/v1/auth/login", json=valid_login)
        assert res_login.status_code == 200, f"Login failed: {res_login.text}"
        token_data = res_login.json()
        assert "access_token" in token_data
        assert "refresh_token" in token_data
        access_token = token_data["access_token"]
        print("Issued JWT Tokens:", token_data)

        print("\n--- 6. Testing GET /api/v1/auth/me Profile ---")
        headers = {"Authorization": f"Bearer {access_token}"}
        res_me = await client.get("/api/v1/auth/me", headers=headers)
        assert res_me.status_code == 200, f"GET /me failed: {res_me.text}"
        me_data = res_me.json()
        assert me_data["email"] == test_email
        print("/me Profile Response:", me_data)

        print("\n--- 7. Testing POST /api/v1/auth/logout ---")
        res_logout = await client.post("/api/v1/auth/logout", headers=headers)
        assert res_logout.status_code == 200, f"Logout failed: {res_logout.text}"
        print("Logout Response:", res_logout.json())

        print(
            "\nALL BACKEND AUTHENTICATION TESTS PASSED SUCCESSFULLY 100%!"
        )


if __name__ == "__main__":
    asyncio.run(test_full_auth_flow())
