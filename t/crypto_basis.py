import hashlib
import hmac
import secrets
import base64
from typing import Callable, List, Dict, Any, Tuple
from dataclasses import dataclass


@dataclass
class CryptoTest:
    name: str
    func: Callable
    inputs: List[Any]
    expected: Any


class CryptoBasis:
	KNOWN_PATTERNS = {
		"identity": b"\x00" * 32,
		"all_ones": b"\xff" * 32,
		"ascii_a": b"a" * 32,
		"ascii_0": b"0" * 32,
		"null_byte": b"\x00",
	}
	
	TestResult = Tuple[str, bool, str, Any, Any]
	
	@staticmethod
	def sha256(data: bytes) -> bytes:
		return hashlib.sha256(data).digest()
	
	@staticmethod
	def sha512(data: bytes) -> bytes:
		return hashlib.sha512(data).digest()
	
	@staticmethod
	def hmac_sha256(key: bytes, data: bytes) -> bytes:
		return hmac.new(key, data, hashlib.sha256).digest()
	
	@staticmethod
	def hmac_sha512(key: bytes, data: bytes) -> bytes:
		return hmac.new(key, data, hashlib.sha512).digest()
	
	@staticmethod
	def random_bytes(n: int) -> bytes:
		return secrets.token_bytes(n)
	
	@staticmethod
	def random_hex(n: int) -> str:
		return secrets.token_hex(n)
	
	@staticmethod
	def pbkdf2(password: bytes, salt: bytes, iterations: int, keylen: int) -> bytes:
		return hashlib.pbkdf2_hmac("sha256", password, salt, iterations, dklen=keylen)
	
	@staticmethod
	def scrypt(password: bytes, salt: bytes, n: int, r: int, p: int, keylen: int) -> bytes:
		return hashlib.scrypt(password, salt=salt, n=n, r=r, p=p, dklen=keylen)
	
	@staticmethod
	def md5(data: bytes) -> bytes:
		return hashlib.md5(data).digest()
	
	@staticmethod
	def sha1(data: bytes) -> bytes:
		return hashlib.sha1(data).digest()
	
	@staticmethod
	def sha384(data: bytes) -> bytes:
		return hashlib.sha384(data).digest()
	
	@staticmethod
	def sha3_256(data: bytes) -> bytes:
		return hashlib.sha3_256(data).digest()
	
	@staticmethod
	def sha3_512(data: bytes) -> bytes:
		return hashlib.sha3_512(data).digest()
	
	@staticmethod
	def blake2b(data: bytes, digest_size: int = 64) -> bytes:
		return hashlib.blake2b(data, digest_size=digest_size).digest()
	
	@staticmethod
	def blake2s(data: bytes, digest_size: int = 32) -> bytes:
		return hashlib.blake2s(data, digest_size=digest_size).digest()


class CryptoTestHarness:
	BASIS_CASES = [
		"empty_input",
		"single_byte",
		"short_string",
		"long_input",
		"binary_null",
		"repetition",
		"boundary_values",
		"random_input",
	]
	
	def __init__(self):
		self.results: List[CryptoBasis.TestResult] = []
		self.test_vectors: Dict[str, bytes] = {}
		self._build_test_vectors()
	
	def _build_test_vectors(self):
		self.test_vectors = {
			"empty_input": b"",
			"single_byte": b"x",
			"short_string": b"hello world",
			"long_input": b"a" * 10000,
			"binary_null": b"\x00\x01\x02\x00",
			"repetition": b"\x55" * 256,
			"boundary_values": bytes(range(256)),
			"random_input": CryptoBasis.random_bytes(1024),
		}
	
	def _register_result(self, test_name: str, passed: bool, msg: str, expected: Any, actual: Any):
		self.results.append((test_name, passed, msg, expected, actual))
	
	def test_hash_function(self, name: str, func: Callable[[bytes], bytes]) -> bool:
		all_passed = True
		for case_name, input_data in self.test_vectors.items():
			try:
				result = func(input_data)
				if result is None or len(result) == 0:
					self._register_result(f"{name}_{case_name}", False, "empty result", "non-empty", result)
					all_passed = False
				else:
					self._register_result(f"{name}_{case_name}", True, "ok", len(result), len(result))
			except Exception as e:
				self._register_result(f"{name}_{case_name}", False, str(e), "no error", str(e))
				all_passed = False
		return all_passed
	
	def test_hmac_function(self, name: str, func: Callable[[bytes, bytes], bytes]) -> bool:
		all_passed = True
		key = CryptoBasis.random_bytes(32)
		for case_name, input_data in self.test_vectors.items():
			try:
				result = func(key, input_data)
				if result is None or len(result) == 0:
					self._register_result(f"{name}_{case_name}", False, "empty result", "non-empty", result)
					all_passed = False
				else:
					self._register_result(f"{name}_{case_name}", True, "ok", len(result), len(result))
			except Exception as e:
				self._register_result(f"{name}_{case_name}", False, str(e), "no error", str(e))
				all_passed = False
		return all_passed
	
	def test_deterministic(self, func: Callable[[bytes], bytes], input_name: str = "test") -> bool:
		input_data = self.test_vectors[input_name]
		r1 = func(input_data)
		r2 = func(input_data)
		is_equal = r1 == r2
		self._register_result(f"deterministic_{input_name}", is_equal, "consistent output", r1, r2)
		return is_equal
	
	def test_collision_resistance(self, func: Callable[[bytes], bytes], sample_count: int = 100) -> bool:
		hashes = set()
		all_unique = True
		for i in range(sample_count):
			data = f"test_{i}".encode()
			h = func(data)
			if h in hashes:
				all_unique = False
				break
			hashes.add(h)
		self._register_result("collision_resistance", all_unique, f"{sample_count} unique", "unique", all_unique)
		return all_unique
	
	def test_output_lengths(self, func: Callable[[bytes], bytes], expected_lengths: List[int]) -> bool:
		all_passed = True
		input_data = b"test"
		result = func(input_data)
		if len(result) not in expected_lengths:
			self._register_result("output_length", False, f"got {len(result)}", expected_lengths, len(result))
			return False
		self._register_result("output_length", True, "ok", expected_lengths, len(result))
		return True
	
	def test_known_answer(self, func: Callable, input_data: bytes, expected: bytes, test_name: str) -> bool:
		result = func(input_data)
		is_equal = result == expected
		self._register_result(test_name, is_equal, "known answer", expected.hex(), result.hex())
		return is_equal
	
	def run_all_tests(self) -> Dict[str, Any]:
		passed = 0
		failed = 0
		
		print("=" * 60)
		print("PYTHON CRYPTOGRAPHY TEST HARNESS")
		print("=" * 60)
		
		self.test_hash_function("sha256", CryptoBasis.sha256)
		self.test_hash_function("sha512", CryptoBasis.sha512)
		self.test_hash_function("md5", CryptoBasis.md5)
		self.test_hash_function("sha1", CryptoBasis.sha1)
		self.test_hash_function("sha384", CryptoBasis.sha384)
		self.test_hash_function("sha3_256", CryptoBasis.sha3_256)
		self.test_hash_function("sha3_512", CryptoBasis.sha3_512)
		self.test_hash_function("blake2b", CryptoBasis.blake2b)
		self.test_hash_function("blake2s", CryptoBasis.blake2s)
		
		self.test_hmac_function("hmac_sha256", CryptoBasis.hmac_sha256)
		self.test_hmac_function("hmac_sha512", CryptoBasis.hmac_sha512)
		
		self.test_deterministic(CryptoBasis.sha256, "empty_input")
		self.test_deterministic(CryptoBasis.sha256, "single_byte")
		self.test_deterministic(CryptoBasis.sha256, "short_string")
		
		self.test_collision_resistance(CryptoBasis.sha256)
		
		self.test_output_lengths(CryptoBasis.sha256, [32])
		self.test_output_lengths(CryptoBasis.sha512, [64])
		
		known_answers = [
			("sha256", CryptoBasis.sha256, b"", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
			("sha256", CryptoBasis.sha256, b"abc", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad".encode()),
			("sha256", CryptoBasis.sha256, b"hello world", "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9".encode()),
		]
		for name, func, inp, exp in known_answers:
			self.test_known_answer(func, inp, exp, f"kat_{name}")
		
		for name, passed_val, msg, exp, act in self.results:
			status = "PASS" if passed_val else "FAIL"
			print(f"[{status}] {name}: {msg}")
			if passed_val:
				passed += 1
			else:
				failed += 1
		
		print("=" * 60)
		print(f"RESULTS: {passed} passed, {failed} failed")
		print("=" * 60)
		
		return {"passed": passed, "failed": failed, "total": passed + failed}


def main():
	harness = CryptoTestHarness()
	results = harness.run_all_tests()
	
	if results["failed"] > 0:
		print(f"\nCRITICAL: {results['failed']} tests failed!")
		return 1
	print("\nAll crypto basis tests passed!")
	return 0


if __name__ == "__main__":
	exit(main())