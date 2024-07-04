package pkcs

import (
	"crypto/sha1"
	"crypto/sha256"
	"crypto/sha512"
	"crypto/x509/pkix"
	"encoding/asn1"
	"errors"
	"fmt"
	"hash"
	"io"
	"strconv"

	"github.com/emmansun/gmsm/sm3"
)

var (
	oidPBES2 = asn1.ObjectIdentifier{1, 2, 840, 113549, 1, 5, 13}
)

// Hash identifies a cryptographic hash function that is implemented in another
// package.
type Hash uint

const (
	SHA1 Hash = 1 + iota
	SHA224
	SHA256
	SHA384
	SHA512
	SHA512_224
	SHA512_256
	SM3
)

// New returns a new hash.Hash calculating the given hash function. New panics
// if the hash function is not linked into the binary.
func (h Hash) New() hash.Hash {
	switch h {
	case SM3:
		return sm3.New()
	case SHA1:
		return sha1.New()
	case SHA224:
		return sha256.New224()
	case SHA256:
		return sha256.New()
	case SHA384:
		return sha512.New384()
	case SHA512:
		return sha512.New()
	case SHA512_224:
		return sha512.New512_224()
	case SHA512_256:
		return sha512.New512_256()

	}
	panic("pkcs5: requested hash function #" + strconv.Itoa(int(h)) + " is unavailable")
}

// PBKDF2Opts contains algorithm identifiers and related parameters for PBKDF2 key derivation function.
type PBES2Params struct {
	KeyDerivationFunc pkix.AlgorithmIdentifier
	EncryptionScheme  pkix.AlgorithmIdentifier
}

// PBES2Opts contains options for encrypting a key using PBES2.
type PBES2Opts struct {
	Cipher
	KDFOpts
}

// DefaultOpts are the default options for encrypting a key if none are given.
// The defaults can be changed by the library user.
var DefaultOpts = &PBES2Opts{
	Cipher: AES256CBC,
	KDFOpts: PBKDF2Opts{
		SaltSize:       16,
		IterationCount: 2048,
		HMACHash:       SHA256,
	},
}

// KDFOpts contains options for a key derivation function.
// An implementation of this interface must be specified when encrypting a PKCS#8 key.
type KDFOpts interface {
	// DeriveKey derives a key of size bytes from the given password and salt.
	// It returns the key and the ASN.1-encodable parameters used.
	DeriveKey(password, salt []byte, size int) (key []byte, params KDFParameters, err error)
	// GetSaltSize returns the salt size specified.
	GetSaltSize() int
	// OID returns the OID of the KDF specified.
	OID() asn1.ObjectIdentifier
}

// KDFParameters contains parameters (salt, etc.) for a key deriviation function.
// It must be a ASN.1-decodable structure.
// An implementation of this interface is created when decoding an encrypted PKCS#8 key.
type KDFParameters interface {
	// DeriveKey derives a key of size bytes from the given password.
	// It uses the salt from the decoded parameters.
	DeriveKey(password []byte, size int) (key []byte, err error)
}

var kdfs = make(map[string]func() KDFParameters)

// RegisterKDF registers a function that returns a new instance of the given KDF
// parameters. This allows the library to support client-provided KDFs.
func RegisterKDF(oid asn1.ObjectIdentifier, params func() KDFParameters) {
	kdfs[oid.String()] = params
}

func (pbes2Params *PBES2Params) parseKeyDerivationFunc() (KDFParameters, error) {
	oid := pbes2Params.KeyDerivationFunc.Algorithm.String()
	newParams, ok := kdfs[oid]
	if !ok {
		return nil, fmt.Errorf("pkcs5: unsupported KDF (OID: %s)", oid)
	}
	params := newParams()
	_, err := asn1.Unmarshal(pbes2Params.KeyDerivationFunc.Parameters.FullBytes, params)
	if err != nil {
		return nil, errors.New("pkcs5: invalid KDF parameters")
	}
	return params, nil
}

// Decrypt decrypts the given ciphertext using the given password and the options specified.
func (pbes2Params *PBES2Params) Decrypt(password, ciphertext []byte) ([]byte, KDFParameters, error) {
	cipher, err := GetCipher(pbes2Params.EncryptionScheme)
	if err != nil {
		return nil, nil, err
	}

	kdfParams, err := pbes2Params.parseKeyDerivationFunc()
	if err != nil {
		return nil, nil, err
	}

	keySize := cipher.KeySize()
	symkey, err := kdfParams.DeriveKey(password, keySize)
	if err != nil {
		return nil, nil, err
	}

	plaintext, err := cipher.Decrypt(symkey, &pbes2Params.EncryptionScheme.Parameters, ciphertext)
	if err != nil {
		return nil, nil, err
	}
	return plaintext, kdfParams, nil
}

// Encrypt encrypts the given plaintext using the given password and the options specified.
func (opts *PBES2Opts) Encrypt(rand io.Reader, password, plaintext []byte) (*pkix.AlgorithmIdentifier, []byte, error) {
	// Generate a random salt
	salt := make([]byte, opts.KDFOpts.GetSaltSize())
	if _, err := rand.Read(salt); err != nil {
		return nil, nil, err
	}

	// Derive the key
	encAlg := opts.Cipher
	key, kdfParams, err := opts.KDFOpts.DeriveKey(password, salt, encAlg.KeySize())
	if err != nil {
		return nil, nil, err
	}

	// Encrypt the plaintext
	encryptionScheme, ciphertext, err := encAlg.Encrypt(rand, key, plaintext)
	if err != nil {
		return nil, nil, err
	}

	marshalledParams, err := asn1.Marshal(kdfParams)
	if err != nil {
		return nil, nil, err
	}
	keyDerivationFunc := pkix.AlgorithmIdentifier{
		Algorithm:  opts.KDFOpts.OID(),
		Parameters: asn1.RawValue{FullBytes: marshalledParams},
	}

	encryptionAlgorithmParams := PBES2Params{
		EncryptionScheme:  *encryptionScheme,
		KeyDerivationFunc: keyDerivationFunc,
	}
	marshalledEncryptionAlgorithmParams, err := asn1.Marshal(encryptionAlgorithmParams)
	if err != nil {
		return nil, nil, err
	}
	encryptionAlgorithm := pkix.AlgorithmIdentifier{
		Algorithm:  oidPBES2,
		Parameters: asn1.RawValue{FullBytes: marshalledEncryptionAlgorithmParams},
	}
	return &encryptionAlgorithm, ciphertext, nil
}

func IsPBES2(algorithm pkix.AlgorithmIdentifier) bool {
	return oidPBES2.Equal(algorithm.Algorithm)
}
