//go:build amd64 || arm64
// +build amd64 arm64

package sm4

import (
	"fmt"
	"testing"
)

func genPrecomputeTable() *gcmAsm {
	key := []byte{0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10}
	c := sm4CipherAsm{sm4Cipher{make([]uint32, rounds), make([]uint32, rounds)}}
	expandKeyAsm(&key[0], &ck[0], &c.enc[0], &c.dec[0])
	c1 := &sm4CipherGCM{c}
	g := &gcmAsm{}
	g.cipher = &c1.sm4CipherAsm
	var key1 [gcmBlockSize]byte
	c1.Encrypt(key1[:], key1[:])
	fmt.Printf("%v\n", key1)
	precomputeTableAsm(&g.bytesProductTable, &key1)
	return g
}

/*
amd64 result = 	{
		0xEF, 0xE0, 0x28, 0x75, 0x21, 0x1F, 0x10, 0x4B, 0x6C, 0xC6, 0x39, 0x8A, 0x88, 0xE0, 0x26, 0x16,
		0x83, 0x26, 0x11, 0xFF, 0xA9, 0xFF, 0x36, 0x5D, 0x83, 0x26, 0x11, 0xFF, 0xA9, 0xFF, 0x36, 0x5D,
		0xD1, 0x99, 0x07, 0x39, 0xBA, 0x15, 0x68, 0xA7, 0xB8, 0x50, 0xC2, 0xB3, 0xD6, 0xFA, 0xA7, 0x02,
		0x69, 0xC9, 0xC5, 0x8A, 0x6C, 0xEF, 0xCF, 0xA5, 0x69, 0xC9, 0xC5, 0x8A, 0x6C, 0xEF, 0xCF, 0xA5,
		0xC4, 0x65, 0xCA, 0xCA, 0x55, 0x7F, 0x2B, 0x72, 0xB1, 0xA4, 0x14, 0x62, 0xDE, 0xBD, 0x1B, 0x00,
		0x75, 0xC1, 0xDE, 0xA8, 0x8B, 0xC2, 0x30, 0x72, 0x75, 0xC1, 0xDE, 0xA8, 0x8B, 0xC2, 0x30, 0x72,
		0x85, 0xF6, 0x58, 0x15, 0x09, 0x45, 0xB9, 0x72, 0x00, 0x30, 0xAB, 0x91, 0x2A, 0x73, 0xB7, 0x1C,
		0x85, 0xC6, 0xF3, 0x84, 0x23, 0x36, 0x0E, 0x6E, 0x85, 0xC6, 0xF3, 0x84, 0x23, 0x36, 0x0E, 0x6E,
		0x70, 0xD7, 0xD2, 0x6D, 0x60, 0xBA, 0x5E, 0x2E, 0x43, 0x4C, 0x4A, 0xCF, 0xFA, 0xE2, 0xF1, 0x5B,
		0x33, 0x9B, 0x98, 0xA2, 0x9A, 0x58, 0xAF, 0x75, 0x33, 0x9B, 0x98, 0xA2, 0x9A, 0x58, 0xAF, 0x75,
		0xED, 0xEB, 0x6C, 0xD4, 0x1B, 0x6C, 0x86, 0x6A, 0xA1, 0x16, 0xA5, 0xFF, 0x33, 0xDC, 0xBB, 0xC0,
		0x4C, 0xFD, 0xC9, 0x2B, 0x28, 0xB0, 0x3D, 0xAA, 0x4C, 0xFD, 0xC9, 0x2B, 0x28, 0xB0, 0x3D, 0xAA,
		0xBF, 0x7C, 0x2D, 0x4E, 0xFD, 0xDD, 0x55, 0x77, 0x1C, 0x7E, 0x73, 0xC7, 0xAA, 0x8B, 0x73, 0x2F,
		0xA3, 0x02, 0x5E, 0x89, 0x57, 0x56, 0x26, 0x58, 0xA3, 0x02, 0x5E, 0x89, 0x57, 0x56, 0x26, 0x58,
		0x54, 0x44, 0xA9, 0xB7, 0x20, 0x66, 0xAA, 0x2E, 0x99, 0x45, 0x82, 0x13, 0xD6, 0xE8, 0xEF, 0x4C,
		0xCD, 0x01, 0x2B, 0xA4, 0xF6, 0x8E, 0x45, 0x62, 0xCD, 0x01, 0x2B, 0xA4, 0xF6, 0x8E, 0x45, 0x62, }
arm64 result = {
		0x6C, 0xC6, 0x39, 0x8A, 0x88, 0xE0, 0x26, 0x16, 0xEF, 0xE0, 0x28, 0x75, 0x21, 0x1F, 0x10, 0x4B,
		0x83, 0x26, 0x11, 0xFF, 0xA9, 0xFF, 0x36, 0x5D, 0x83, 0x26, 0x11, 0xFF, 0xA9, 0xFF, 0x36, 0x5D,
		0xB8, 0x50, 0xC2, 0xB3, 0xD6, 0xFA, 0xA7, 0x02, 0xD1, 0x99, 0x07, 0x39, 0xBA, 0x15, 0x68, 0xA7,
		0x69, 0xC9, 0xC5, 0x8A, 0x6C, 0xEF, 0xCF, 0xA5, 0x69, 0xC9, 0xC5, 0x8A, 0x6C, 0xEF, 0xCF, 0xA5,
		0xB1, 0xA4, 0x14, 0x62, 0xDE, 0xBD, 0x1B, 0x00, 0xC4, 0x65, 0xCA, 0xCA, 0x55, 0x7F, 0x2B, 0x72,
		0x75, 0xC1, 0xDE, 0xA8, 0x8B, 0xC2, 0x30, 0x72, 0x75, 0xC1, 0xDE, 0xA8, 0x8B, 0xC2, 0x30, 0x72,
		0x00, 0x30, 0xAB, 0x91, 0x2A, 0x73, 0xB7, 0x1C, 0x85, 0xF6, 0x58, 0x15, 0x09, 0x45, 0xB9, 0x72,
		0x85, 0xC6, 0xF3, 0x84, 0x23, 0x36, 0x0E, 0x6E, 0x85, 0xC6, 0xF3, 0x84, 0x23, 0x36, 0x0E, 0x6E,
		0x43, 0x4C, 0x4A, 0xCF, 0xFA, 0xE2, 0xF1, 0x5B, 0x70, 0xD7, 0xD2, 0x6D, 0x60, 0xBA, 0x5E, 0x2E,
		0x33, 0x9B, 0x98, 0xA2, 0x9A, 0x58, 0xAF, 0x75, 0x33, 0x9B, 0x98, 0xA2, 0x9A, 0x58, 0xAF, 0x75,
		0xA1, 0x16, 0xA5, 0xFF, 0x33, 0xDC, 0xBB, 0xC0, 0xED, 0xEB, 0x6C, 0xD4, 0x1B, 0x6C, 0x86, 0x6A,
		0x4C, 0xFD, 0xC9, 0x2B, 0x28, 0xB0, 0x3D, 0xAA, 0x4C, 0xFD, 0xC9, 0x2B, 0x28, 0xB0, 0x3D, 0xAA,
		0x1C, 0x7E, 0x73, 0xC7, 0xAA, 0x8B, 0x73, 0x2F, 0xBF, 0x7C, 0x2D, 0x4E, 0xFD, 0xDD, 0x55, 0x77,
		0xA3, 0x02, 0x5E, 0x89, 0x57, 0x56, 0x26, 0x58, 0xA3, 0x02, 0x5E, 0x89, 0x57, 0x56, 0x26, 0x58,
		0x99, 0x45, 0x82, 0x13, 0xD6, 0xE8, 0xEF, 0x4C, 0x54, 0x44, 0xA9, 0xB7, 0x20, 0x66, 0xAA, 0x2E,
		0xCD, 0x01, 0x2B, 0xA4, 0xF6, 0x8E, 0x45, 0x62, 0xCD, 0x01, 0x2B, 0xA4, 0xF6, 0x8E, 0x45, 0x62,
}
*/
func TestPrecomputeTableAsm(t *testing.T) {
	g := genPrecomputeTable()
	for i := 0; i < 16; i++ {
		for j := 0; j < 16; j++ {
			fmt.Printf("0x%02X, ", g.bytesProductTable[i*16+j])
		}
		fmt.Println()
	}
}

/*
amd64 result = {
	7D 13 81 A2 78 ED 2D 5E 91 3E 7F 9A 15 2C 76 DA
}

arm64 result = {
	91 3E 7F 9A 15 2C 76 DA 7D 13 81 A2 78 ED 2D 5E
}
*/
func TestGcmSm4Data(t *testing.T) {
	g := genPrecomputeTable()
	var counter [gcmBlockSize]byte
	nonce := []byte{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13}
	gcmSm4Data(&g.bytesProductTable, nonce, &counter)
	for j := 0; j < 16; j++ {
		fmt.Printf("%02X ", counter[j])
	}
	fmt.Println()
}

/*
amd64 result = {
	8F F3 05 10 EA 99 A8 D7 41 D9 E3 BA 67 D6 18 EE
}
arm64 result = {
	8F F3 05 10 EA 99 A8 D7 41 D9 E3 BA 67 D6 18 EE
}
*/
func TestGcmSm4Finish(t *testing.T) {
	g := genPrecomputeTable()
	var counter, tagMask [gcmBlockSize]byte
	nonce := []byte{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13}
	gcmSm4Data(&g.bytesProductTable, nonce, &counter)
	gcmSm4Finish(&g.bytesProductTable, &tagMask, &counter, uint64(len(nonce)), uint64(0))
	for j := 0; j < 16; j++ {
		fmt.Printf("%02X ", counter[j])
	}
	fmt.Println()
}

func TestBothDataPlaintext(t *testing.T) {
	g := genPrecomputeTable()
	var tagOut, tagMask [gcmBlockSize]byte
	data := []byte("emmansun")
	gcmSm4Data(&g.bytesProductTable, data, &tagOut)
	for j := 0; j < 16; j++ {
		tagMask[j] = byte(j)
	}
	for j := 0; j < 16; j++ {
		fmt.Printf("%02X ", tagOut[j])
	}
	fmt.Println()
	gcmSm4Data(&g.bytesProductTable, []byte("emmansunemmansunemmansunemmansun"), &tagOut)
	for j := 0; j < 16; j++ {
		fmt.Printf("%02X ", tagOut[j])
	}
	fmt.Println()
	gcmSm4Finish(&g.bytesProductTable, &tagMask, &tagOut, uint64(32), uint64(8))
	for j := 0; j < 16; j++ {
		fmt.Printf("%02X ", tagOut[j])
	}
	fmt.Println()
}
