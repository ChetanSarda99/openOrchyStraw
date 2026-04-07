"""User authentication module — has NO tests. Agent should create them."""

import hashlib
import re
from datetime import datetime, timedelta


class AuthError(Exception):
    """Raised on authentication failures."""
    pass


class User:
    def __init__(self, username, email, password):
        self.username = username
        self.email = email
        self._password_hash = self._hash_password(password)
        self.created_at = datetime.utcnow()
        self.login_attempts = 0
        self.locked_until = None

    @staticmethod
    def _hash_password(password):
        return hashlib.sha256(password.encode()).hexdigest()

    def check_password(self, password):
        return self._password_hash == self._hash_password(password)

    def is_locked(self):
        if self.locked_until is None:
            return False
        if datetime.utcnow() >= self.locked_until:
            self.locked_until = None
            self.login_attempts = 0
            return False
        return True


def validate_email(email):
    """Basic email validation."""
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return bool(re.match(pattern, email))


def validate_password(password):
    """Password must be 8+ chars with at least one digit and one uppercase."""
    if len(password) < 8:
        return False, "Password must be at least 8 characters"
    if not any(c.isupper() for c in password):
        return False, "Password must contain at least one uppercase letter"
    if not any(c.isdigit() for c in password):
        return False, "Password must contain at least one digit"
    return True, "OK"


def authenticate(user, password, max_attempts=5, lockout_minutes=15):
    """Authenticate a user with lockout after max_attempts failures."""
    if user.is_locked():
        raise AuthError(f"Account locked until {user.locked_until}")

    if user.check_password(password):
        user.login_attempts = 0
        return True

    user.login_attempts += 1
    if user.login_attempts >= max_attempts:
        user.locked_until = datetime.utcnow() + timedelta(minutes=lockout_minutes)
        raise AuthError("Account locked due to too many failed attempts")

    return False


def register_user(username, email, password, existing_users=None):
    """Register a new user with validation."""
    if not username or len(username) < 3:
        raise ValueError("Username must be at least 3 characters")

    if not validate_email(email):
        raise ValueError(f"Invalid email: {email}")

    valid, msg = validate_password(password)
    if not valid:
        raise ValueError(msg)

    if existing_users:
        for u in existing_users:
            if u.username == username:
                raise ValueError(f"Username '{username}' already taken")
            if u.email == email:
                raise ValueError(f"Email '{email}' already registered")

    return User(username, email, password)
