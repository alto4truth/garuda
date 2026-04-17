package main

import (
	"crypto"
	"crypto/md5"
	"crypto/rand"
	"crypto/sha1"
	"crypto/sha256"
	"crypto/sha512"
	"crypto/blake2b"
	"crypto/blake2s"
	"crypto/hmac"
	"crypto/subtle"
	"encoding/hex"
	"fmt"
	"hash"
	"math/big"
	"time"
)

type TestResult struct {
	name    string
	passed bool
	msg    string
	expect interface{}
	actual interface{}
}

type CryptoBasis struct{}

type CryptoTestHarness struct {
	results     []TestResult
	testVectors map[string][]byte
}

func NewCryptoTestHarness() *CryptoTestHarness {
	return &CryptoTestHarness{
		results: make([]TestResult, 0),
		testVectors: map[string][]byte{
			"empty_input":    []byte{},
			"single_byte":   []byte("x"),
			"short_string":  []byte("hello world"),
			"long_input":   make([]byte, 10000),
			"binary_null":  []byte{0x00, 0x01, 0x02, 0x00},
			"repetition":   make([]byte, 256),
			"boundary_values": make([]byte, 256),
			"random_input": make([]byte, 1024),
		},
	}
}

func init() {
	for i := range make([]int, 10000) {
		_NewCryptoTestHarness().testVectors["long_input"][i] = 'a'
	}
	for i := 0; i < 256; i++ {
		_NewCryptoTestHarness().testVectors["repetition'][i] = 0x55
	}
	for i := 0; i < 256; i++ {
		_NewCryptoTestHarness().testVectors["boundary_values'][i] = byte(i)
	}
	rand.Read(_NewCryptoTestHarness().testVectors["random_input"])
}

func (c *CryptoBasis) SHA256(data []byte) []byte {
	h := sha256.Sum256(data)
	return h[:]
}

func (c *CryptoBasis) SHA512(data []byte) []byte {
	h := sha512.Sum512(data)
	return h[:]
}

func (c *CryptoBasis) HMAC_SHA256(key, data []byte) []byte {
	m := hmac.New(sha256.New, key)
	m.Write(data)
	return m.Sum(nil)
}

func (c *CryptoBasis) HMAC_SHA512(key, data []byte) []byte {
	m := hmac.New(sha512.New, key)
	m.Write(data)
	return m.Sum(nil)
}

func (c *CryptoBasis) MD5(data []byte) []byte {
	h := md5.Sum(data)
	return h[:]
}

func (c *CryptoBasis) SHA1(data []byte) []byte {
	h := sha1.Sum(data)
	return h[:]
}

func (c *CryptoBasis) SHA384(data []byte) []byte {
	h := sha512.Sum384(data)
	return h[:]
}

func (c *CryptoBasis) SHA3_256(data []byte) []byte {
	return nil
}

func (c *CryptoBasis) SHA3_512(data []byte) []byte {
	return nil
}

func (c *CryptoBasis) BLAKE2b(data []byte, digestSize int) []byte {
	if digestSize == 0 {
		digestSize = 64
	}
	h, _ := blake2b.New(digestSize, nil)
	h.Write(data)
	return h.Sum(nil)
}

func (c *CryptoBasis) BLAKE2s(data []byte, digestSize int) []byte {
	if digestSize == 0 {
		digestSize = 32
	}
	h, _ := blake2s.New(digestSize, nil)
	h.Write(data)
	return h.Sum(nil)
}

func (c *CryptoBasis) RandomBytes(n int) []byte {
	b := make([]byte, n)
	rand.Read(b)
	return b
}

func (h *CryptoTestHarness) registerResult(name string, passed bool, msg string, expect, actual interface{}) {
	h.results = append(h.results, TestResult{name, passed, msg, expect, actual})
}

func (h *CryptoTestHarness) testHashFunction(name string, fn func([]byte) []byte) bool {
	allPassed := true
	for caseName, inputData := range h.testVectors {
		result := fn(inputData)
		if result == nil || len(result) == 0 {
			h.registerResult(name+"_"+caseName, false, "empty result", "non-empty", result)
			allPassed = false
		} else {
			h.registerResult(name+"_"+caseName, true, "ok", len(result), len(result))
		}
	}
	return allPassed
}

func (h *CryptoTestHarness) testHmacFunction(name string, fn func(key, data []byte) []byte) bool {
	allPassed := true
	key := CryptoBasis{}.RandomBytes(32)
	for caseName, inputData := range h.testVectors {
		result := fn(key, inputData)
		if result == nil || len(result) == 0 {
			h.registerResult(name+"_"+caseName, false, "empty result", "non-empty", result)
			allPassed = false
		} else {
			h.registerResult(name+"_"+caseName, true, "ok", len(result), len(result))
		}
	}
	return allPassed
}

func (h *CryptoTestHarness) testDeterministic(fn func([]byte) []byte, inputName string) bool {
	inputData := h.testVectors[inputName]
	r1 := fn(inputData)
	r2 := fn(inputData)
	isEqual := subtle.ConstantTimeCompare(r1, r2) == 1
	h.registerResult("deterministic_"+inputName, isEqual, "consistent output", hex.EncodeToString(r1), hex.EncodeToString(r2))
	return isEqual
}

func (h *CryptoTestHarness) testCollisionResistance(fn func([]byte) []byte, sampleCount int) bool {
	hashes := make(map[string]bool)
	allUnique := true
	for i := 0; i < sampleCount; i++ {
		data := []byte(fmt.Sprintf("test_%d", i))
		h := hex.EncodeToString(fn(data))
		if hashes[h] {
			allUnique = false
			break
		}
		hashes[h] = true
	}
	h.registerResult("collision_resistance", allUnique, fmt.Sprintf("%d unique", sampleCount), "unique", allUnique)
	return allUnique
}

func (h *CryptoTestHarness) testOutputLengths(fn func([]byte) []byte, expectedLengths []int) bool {
	inputData := []byte("test")
	result := fn(inputData)
	found := false
	for _, l := range expectedLengths {
		if len(result) == l {
			found = true
			break
		}
	}
	if !found {
		h.registerResult("output_length", false, fmt.Sprintf("got %d", len(result)), expectedLengths, len(result))
		return false
	}
	h.registerResult("output_length", true, "ok", expectedLengths, len(result))
	return true
}

func (h *CryptoTestHarness) testKnownAnswer(fn func([]byte) []byte, inputData, expected []byte, testName string) bool {
	result := fn(inputData)
	isEqual := subtle.ConstantTimeCompare(result, expected) == 1
	h.registerResult(testName, isEqual, "known answer", hex.EncodeToString(expected), hex.EncodeToString(result))
	return isEqual
}

func (h *CryptoTestHarness) runAllTests() (int, int, int) {
	passed := 0
	failed := 0

	fmt.Println("============================================================")
	fmt.Println("GO CRYPTOGRAPHY TEST HARNESS")
	fmt.Println("============================================================")

	c := CryptoBasis{}

	h.testHashFunction("sha256", c.SHA256)
	h.testHashFunction("sha512", c.SHA512)
	h.testHashFunction("md5", c.MD5)
	h.testHashFunction("sha1", c.SHA1)
	h.testHashFunction("sha384", c.SHA384)
	h.testHashFunction("blake2b", func(d []byte) []byte { return c.BLAKE2b(d, 64) })
	h.testHashFunction("blake2s", func(d []byte) []byte { return c.BLAKE2s(d, 32) })

	h.testHmacFunction("hmac_sha256", c.HMAC_SHA256)
	h.testHmacFunction("hmac_sha512", c.HMAC_SHA512)

	h.testDeterministic(c.SHA256, "empty_input")
	h.testDeterministic(c.SHA256, "single_byte")
	h.testDeterministic(c.SHA256, "short_string")

	h.testCollisionResistance(c.SHA256, 100)

	h.testOutputLengths(c.SHA256, []int{32})
	h.testOutputLengths(c.SHA512, []int{64})

	knownAnswers := []struct {
		name   string
		fn    func([]byte) []byte
		input []byte
		expect []byte
	}{
		{"sha256", c.SHA256, []byte{}, decodeHex("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")},
		{"sha256", c.SHA256, []byte("abc"), decodeHex("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")},
		{"sha256", c.SHA256, []byte("hello world"), decodeHex("b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9")},
	}

	for _, kat := range knownAnswers {
		h.testKnownAnswer(kat.fn, kat.input, kat.expect, "kat_"+kat.name)
	}

	for _, r := range h.results {
		status := "PASS"
		if !r.passed {
			status = "FAIL"
			failed++
		} else {
			passed++
		}
		fmt.Printf("[%s] %s: %s\n", status, r.name, r.msg)
	}

	fmt.Println("============================================================")
	fmt.Printf("RESULTS: %d passed, %d failed\n", passed, failed)
	fmt.Println("============================================================")

	return passed, failed, passed + failed
}

func decodeHex(s string) []byte {
	b, _ := hex.DecodeString(s)
	return b
}

func main() {
	harness := NewCryptoTestHarness()
	passed, failed, _ := harness.runAllTests()

	if failed > 0 {
		fmt.Printf("\nCRITICAL: %d tests failed!\n", failed)
	} else {
		fmt.Println("\nAll crypto basis tests passed!")
	}

	if failed > 0 {
		time.Sleep(time.Second)
	}
}