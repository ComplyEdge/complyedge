"""ComplyEdge origin signature on anchor statements (GAP-TR-03 / tech-spec §13).

Signs the same statement bytes the TSA timestamps. Proves the producer (CE)
asserted that chain head; not an eIDAS qualified seal. Hot /v1/check path never
calls this — only the hourly anchor job (and tests).

When ``AUDIT_ORIGIN_KMS_KEY_ID`` is unset, signing is skipped so AUD-012 can
deploy before the origin key exists. When set, every stored anchor carries
``signatures: [{alg, key_ref, value}]``.
"""

from __future__ import annotations

import base64
import os
from collections.abc import Callable
from typing import Any

# KMS SigningAlgorithm for ECC_NIST_P256 keys.
ORIGIN_ALG = "ECDSA_SHA_256"
DEFAULT_KEY_REF = "https://complyedge.io/producer-profile/keys/origin-p256.spki"


def origin_kms_key_id() -> str | None:
    key = (os.environ.get("AUDIT_ORIGIN_KMS_KEY_ID") or "").strip()
    return key or None


def origin_key_ref() -> str:
    return (os.environ.get("AUDIT_ORIGIN_KEY_REF") or DEFAULT_KEY_REF).strip()


def sign_statement(
    statement: str,
    *,
    kms_client: Any | None = None,
    sign_fn: Callable[[bytes], bytes] | None = None,
) -> dict[str, str] | None:
    """Return one CHN-05 signature object, or None when origin signing is off.

    ``sign_fn`` is for tests (local ECDSA). Production uses KMS when
    ``AUDIT_ORIGIN_KMS_KEY_ID`` is set.
    """
    data = statement.encode("utf-8")
    if sign_fn is not None:
        sig = sign_fn(data)
        return {
            "alg": ORIGIN_ALG,
            "key_ref": origin_key_ref(),
            "value": base64.b64encode(sig).decode("ascii"),
        }
    key_id = origin_kms_key_id()
    if not key_id:
        return None
    client = kms_client
    if client is None:
        import boto3

        client = boto3.client("kms")
    resp = client.sign(
        KeyId=key_id,
        Message=data,
        MessageType="RAW",
        SigningAlgorithm=ORIGIN_ALG,
    )
    sig = resp["Signature"]
    return {
        "alg": ORIGIN_ALG,
        "key_ref": origin_key_ref(),
        "value": base64.b64encode(sig).decode("ascii"),
    }


def verify_statement_signature(
    statement: str,
    signature: dict[str, Any],
    *,
    public_key_spki_der: bytes,
) -> bool:
    """True when ``signature`` is a valid ECDSA-P256/SHA-256 over ``statement``.

    ``public_key_spki_der`` is the SubjectPublicKeyInfo DER from KMS
    GetPublicKey (or a local test key). Wrong alg / empty value → False.
    """
    if str(signature.get("alg") or "") != ORIGIN_ALG:
        return False
    raw_b64 = signature.get("value")
    if not raw_b64:
        return False
    try:
        sig = base64.b64decode(str(raw_b64), validate=True)
    except Exception:
        return False
    from cryptography.exceptions import InvalidSignature
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import ec

    pub = serialization.load_der_public_key(public_key_spki_der)
    if not isinstance(pub, ec.EllipticCurvePublicKey):
        return False
    try:
        # KMS returns IEEE P1363 (r||s) for ECC; cryptography verify expects DER
        # unless we use prehashed + decode. Convert P1363 → DER.
        der_sig = _p1363_to_der(sig, pub.curve.key_size)
        pub.verify(der_sig, statement.encode("utf-8"), ec.ECDSA(hashes.SHA256()))
        return True
    except (InvalidSignature, ValueError):
        return False


def _p1363_to_der(sig: bytes, key_bits: int) -> bytes:
    """Convert IEEE P1363 (r||s) ECDSA signature to DER SEQUENCE."""
    from cryptography.hazmat.primitives.asymmetric.utils import encode_dss_signature

    size = (key_bits + 7) // 8
    if len(sig) == size * 2:
        r = int.from_bytes(sig[:size], "big")
        s = int.from_bytes(sig[size:], "big")
        return encode_dss_signature(r, s)
    # Already DER (some local signers)
    return sig


def local_p256_keypair():
    """Test helper: (private_key, spki_der)."""
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import ec

    priv = ec.generate_private_key(ec.SECP256R1())
    spki = priv.public_key().public_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    return priv, spki


def local_sign_fn(private_key):
    """Return a sign_fn compatible with ``sign_statement`` (P1363 bytes)."""
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.primitives.asymmetric import ec, utils

    def _sign(data: bytes) -> bytes:
        der = private_key.sign(data, ec.ECDSA(hashes.SHA256()))
        r, s = utils.decode_dss_signature(der)
        size = (private_key.curve.key_size + 7) // 8
        return r.to_bytes(size, "big") + s.to_bytes(size, "big")

    return _sign
