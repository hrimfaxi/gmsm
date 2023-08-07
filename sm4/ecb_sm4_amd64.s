//go:build amd64 && !purego
// +build amd64,!purego

#include "textflag.h"

#include "aesni_macros_amd64.s"

#define XDWTMP0 Y0
#define XDWTMP1 Y1

#define XDWORD0 Y4
#define XDWORD1 Y5
#define XDWORD2 Y6
#define XDWORD3 Y7

#define XDWORD4 Y10
#define XDWORD5 Y11
#define XDWORD6 Y12
#define XDWORD7 Y14

#define XWTMP0 X0
#define XWTMP1 X1
#define XWTMP2 X2

#define XWORD0 X4
#define XWORD1 X5
#define XWORD2 X6
#define XWORD3 X7

#define XWORD4 X10
#define XWORD5 X11
#define XWORD6 X12
#define XWORD7 X14

#define NIBBLE_MASK Y3
#define X_NIBBLE_MASK X3

#define BYTE_FLIP_MASK 	Y13 // mask to convert LE -> BE
#define X_BYTE_FLIP_MASK 	X13 // mask to convert LE -> BE

#define BSWAP_MASK Y2

#define XDWORD Y8
#define YDWORD Y9

#define XWORD X8
#define YWORD X9

// func encryptSm4Ecb(xk *uint32, dst, src []byte)
TEXT ·encryptSm4Ecb(SB),NOSPLIT,$0
	MOVQ xk+0(FP), AX
	MOVQ dst+8(FP), BX
	MOVQ src+32(FP), DX
	MOVQ src_len+40(FP), DI

	CMPB ·useAVX2(SB), $1
	JE   avx2_start

	CMPB ·useAVX(SB), $1
	JE   avxEcbSm4Octets

ecbSm4Octets:
	CMPQ DI, $128
	JB ecbSm4Nibbles
	SUBQ $128, DI

	MOVOU 0(DX), XWORD0
	MOVOU 16(DX), XWORD1
	MOVOU 32(DX), XWORD2
	MOVOU 48(DX), XWORD3
	MOVOU 64(DX), XWORD4
	MOVOU 80(DX), XWORD5
	MOVOU 96(DX), XWORD6
	MOVOU 112(DX), XWORD7

	SM4_8BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3, XWORD4, XWORD5, XWORD6, XWORD7)
	
	MOVOU XWORD0, 0(BX)
	MOVOU XWORD1, 16(BX)
	MOVOU XWORD2, 32(BX)
	MOVOU XWORD3, 48(BX)
	MOVOU XWORD4, 64(BX)
	MOVOU XWORD5, 80(BX)
	MOVOU XWORD6, 96(BX)
	MOVOU XWORD7, 112(BX)	

	LEAQ 128(BX), BX
	LEAQ 128(DX), DX
	JMP ecbSm4Octets

ecbSm4Nibbles:
	CMPQ DI, $64
	JB ecbSm4Single
	SUBQ $64, DI

	MOVOU 0(DX), XWORD0
	MOVOU 16(DX), XWORD1
	MOVOU 32(DX), XWORD2
	MOVOU 48(DX), XWORD3

	SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)

	MOVUPS XWORD0, 0(BX)
	MOVUPS XWORD1, 16(BX)
	MOVUPS XWORD2, 32(BX)
	MOVUPS XWORD3, 48(BX)

	LEAQ 64(BX), BX
	LEAQ 64(DX), DX

ecbSm4Single:
	TESTQ DI, DI
	JE ecbSm4Done

	MOVOU 0(DX), XWORD0
	CMPQ DI, $32
	JEQ ecbSm4Single32
	CMPQ DI, $48
	JEQ ecbSm4Single48
	SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)
	MOVUPS XWORD0, 0(BX)
	JMP ecbSm4Done

ecbSm4Single32:
	MOVOU 16(DX), XWORD1
	SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)
	MOVUPS XWORD0, 0(BX)
	MOVUPS XWORD1, 16(BX)
	JMP ecbSm4Done

ecbSm4Single48:
	MOVOU 16(DX), XWORD1
	MOVOU 32(DX), XWORD2
	SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)
	MOVUPS XWORD0, 0(BX)
	MOVUPS XWORD1, 16(BX)
	MOVUPS XWORD2, 32(BX)

ecbSm4Done:
	RET

avxEcbSm4Octets:
	CMPQ DI, $128
	JB avxEcbSm4Nibbles
	SUBQ $128, DI

	VMOVDQU 0(DX), XWORD0
	VMOVDQU 16(DX), XWORD1
	VMOVDQU 32(DX), XWORD2
	VMOVDQU 48(DX), XWORD3
	VMOVDQU 64(DX), XWORD4
	VMOVDQU 80(DX), XWORD5
	VMOVDQU 96(DX), XWORD6
	VMOVDQU 112(DX), XWORD7

	AVX_SM4_8BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3, XWORD4, XWORD5, XWORD6, XWORD7)

	VMOVDQU XWORD0, 0(BX)
	VMOVDQU XWORD1, 16(BX)
	VMOVDQU XWORD2, 32(BX)
	VMOVDQU XWORD3, 48(BX)
	VMOVDQU XWORD4, 64(BX)
	VMOVDQU XWORD5, 80(BX)
	VMOVDQU XWORD6, 96(BX)
	VMOVDQU XWORD7, 112(BX)

	LEAQ 128(BX), BX
	LEAQ 128(DX), DX
	JMP avxEcbSm4Octets

avxEcbSm4Nibbles:
	CMPQ DI, $64
	JB avxEcbSm4Single
	SUBQ $64, DI

	VMOVDQU 0(DX), XWORD0
	VMOVDQU 16(DX), XWORD1
	VMOVDQU 32(DX), XWORD2
	VMOVDQU 48(DX), XWORD3

	AVX_SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)

	VMOVDQU XWORD0, 0(BX)
	VMOVDQU XWORD1, 16(BX)
	VMOVDQU XWORD2, 32(BX)
	VMOVDQU XWORD3, 48(BX)

	LEAQ 64(BX), BX
	LEAQ 64(DX), DX

avxEcbSm4Single:
	TESTQ DI, DI
	JE avxEcbSm4Done

	VMOVDQU 0(DX), XWORD0
	CMPQ DI, $32
	JEQ avxEcbSm4Single32
	CMPQ DI, $48
	JEQ avxEcbSm4Single48
	AVX_SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)
	VMOVDQU XWORD0, 0(BX)
	JMP avxEcbSm4Done

avxEcbSm4Single32:
	VMOVDQU 16(DX), XWORD1
	AVX_SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)
	VMOVDQU XWORD0, 0(BX)
	VMOVDQU XWORD1, 16(BX)
	JMP avxEcbSm4Done

avxEcbSm4Single48:
	VMOVDQU 16(DX), XWORD1
	VMOVDQU 32(DX), XWORD2
	AVX_SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)
	VMOVDQU XWORD0, 0(BX)
	VMOVDQU XWORD1, 16(BX)
	VMOVDQU XWORD2, 32(BX)

avxEcbSm4Done:
	RET

avx2_start:
	VBROADCASTI128 nibble_mask<>(SB), NIBBLE_MASK
	VBROADCASTI128 flip_mask<>(SB), BYTE_FLIP_MASK
	VBROADCASTI128 bswap_mask<>(SB), BSWAP_MASK

avx2_16blocks:
	CMPQ DI, $256
	JB avx2EcbSm4Octets
	SUBQ $256, DI

	VMOVDQU 0(DX), XDWORD0
	VMOVDQU 32(DX), XDWORD1
	VMOVDQU 64(DX), XDWORD2
	VMOVDQU 96(DX), XDWORD3
	VMOVDQU 128(DX), XDWORD4
	VMOVDQU 160(DX), XDWORD5
	VMOVDQU 192(DX), XDWORD6
	VMOVDQU 224(DX), XDWORD7

	// Apply Byte Flip Mask: LE -> BE
	VPSHUFB BYTE_FLIP_MASK, XDWORD0, XDWORD0
	VPSHUFB BYTE_FLIP_MASK, XDWORD1, XDWORD1
	VPSHUFB BYTE_FLIP_MASK, XDWORD2, XDWORD2
	VPSHUFB BYTE_FLIP_MASK, XDWORD3, XDWORD3
	VPSHUFB BYTE_FLIP_MASK, XDWORD4, XDWORD4
	VPSHUFB BYTE_FLIP_MASK, XDWORD5, XDWORD5
	VPSHUFB BYTE_FLIP_MASK, XDWORD6, XDWORD6
	VPSHUFB BYTE_FLIP_MASK, XDWORD7, XDWORD7

	// Transpose matrix 4 x 4 32bits word
	TRANSPOSE_MATRIX(XDWORD0, XDWORD1, XDWORD2, XDWORD3, XDWTMP0, XDWTMP1)
	TRANSPOSE_MATRIX(XDWORD4, XDWORD5, XDWORD6, XDWORD7, XDWTMP0, XDWTMP1)

	AVX2_SM4_16BLOCKS(AX, XDWORD, YDWORD, XWORD, YWORD, XDWTMP0, XDWTMP1, XDWORD0, XDWORD1, XDWORD2, XDWORD3, XDWORD4, XDWORD5, XDWORD6, XDWORD7)

	// Transpose matrix 4 x 4 32bits word
	TRANSPOSE_MATRIX(XDWORD0, XDWORD1, XDWORD2, XDWORD3, XDWTMP0, XDWTMP1)
	TRANSPOSE_MATRIX(XDWORD4, XDWORD5, XDWORD6, XDWORD7, XDWTMP0, XDWTMP1)

	VPSHUFB BSWAP_MASK, XDWORD0, XDWORD0
	VPSHUFB BSWAP_MASK, XDWORD1, XDWORD1
	VPSHUFB BSWAP_MASK, XDWORD2, XDWORD2
	VPSHUFB BSWAP_MASK, XDWORD3, XDWORD3
  	VPSHUFB BSWAP_MASK, XDWORD4, XDWORD4
	VPSHUFB BSWAP_MASK, XDWORD5, XDWORD5
	VPSHUFB BSWAP_MASK, XDWORD6, XDWORD6
	VPSHUFB BSWAP_MASK, XDWORD7, XDWORD7

	VMOVDQU XDWORD0, 0(BX)
	VMOVDQU XDWORD1, 32(BX)
	VMOVDQU XDWORD2, 64(BX)
	VMOVDQU XDWORD3, 96(BX)
	VMOVDQU XDWORD4, 128(BX)
	VMOVDQU XDWORD5, 160(BX)
	VMOVDQU XDWORD6, 192(BX)
	VMOVDQU XDWORD7, 224(BX)

	LEAQ 256(BX), BX
	LEAQ 256(DX), DX
	JMP avx2_16blocks

avx2EcbSm4Octets:
	CMPQ DI, $128
	JB avx2EcbSm4Nibbles
	SUBQ $128, DI

	VMOVDQU 0(DX), XDWORD0
	VMOVDQU 32(DX), XDWORD1
	VMOVDQU 64(DX), XDWORD2
	VMOVDQU 96(DX), XDWORD3

	// Apply Byte Flip Mask: LE -> BE
	VPSHUFB BYTE_FLIP_MASK, XDWORD0, XDWORD0
	VPSHUFB BYTE_FLIP_MASK, XDWORD1, XDWORD1
	VPSHUFB BYTE_FLIP_MASK, XDWORD2, XDWORD2
	VPSHUFB BYTE_FLIP_MASK, XDWORD3, XDWORD3

	// Transpose matrix 4 x 4 32bits word
	TRANSPOSE_MATRIX(XDWORD0, XDWORD1, XDWORD2, XDWORD3, XDWTMP0, XDWTMP1)

	AVX2_SM4_8BLOCKS(AX, XDWORD, YDWORD, XWORD, YWORD, XDWTMP0, XDWORD0, XDWORD1, XDWORD2, XDWORD3)

	// Transpose matrix 4 x 4 32bits word
	TRANSPOSE_MATRIX(XDWORD0, XDWORD1, XDWORD2, XDWORD3, XDWTMP0, XDWTMP1)

	VPSHUFB BSWAP_MASK, XDWORD0, XDWORD0
	VPSHUFB BSWAP_MASK, XDWORD1, XDWORD1
	VPSHUFB BSWAP_MASK, XDWORD2, XDWORD2
	VPSHUFB BSWAP_MASK, XDWORD3, XDWORD3

	VMOVDQU XDWORD0, 0(BX)
	VMOVDQU XDWORD1, 32(BX)
	VMOVDQU XDWORD2, 64(BX)
	VMOVDQU XDWORD3, 96(BX)

	LEAQ 128(BX), BX
	LEAQ 128(DX), DX
	JMP avx2EcbSm4Octets

avx2EcbSm4Nibbles:
	CMPQ DI, $64
	JB avx2EcbSm4Single
	SUBQ $64, DI

	VMOVDQU 0(DX), XWORD0
	VMOVDQU 16(DX), XWORD1
	VMOVDQU 32(DX), XWORD2
	VMOVDQU 48(DX), XWORD3

	AVX_SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)

	VMOVDQU XWORD0, 0(BX)
	VMOVDQU XWORD1, 16(BX)
	VMOVDQU XWORD2, 32(BX)
	VMOVDQU XWORD3, 48(BX)

	LEAQ 64(BX), BX
	LEAQ 64(DX), DX

avx2EcbSm4Single:
	TESTQ DI, DI
	JE avx2EcbSm4Done

	VMOVDQU 0(DX), XWORD0
	CMPQ DI, $32
	JEQ avx2EcbSm4Single32
	CMPQ DI, $48
	JEQ avx2EcbSm4Single48
	AVX_SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)
	VMOVDQU XWORD0, 0(BX)
	JMP avx2EcbSm4Done

avx2EcbSm4Single32:
	VMOVDQU 16(DX), XWORD1
	AVX_SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)
	VMOVDQU XWORD0, 0(BX)
	VMOVDQU XWORD1, 16(BX)
	JMP avx2EcbSm4Done

avx2EcbSm4Single48:
	VMOVDQU 16(DX), XWORD1
	VMOVDQU 32(DX), XWORD2
	AVX_SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)
	VMOVDQU XWORD0, 0(BX)
	VMOVDQU XWORD1, 16(BX)
	VMOVDQU XWORD2, 32(BX)

avx2EcbSm4Done:	
	VZEROUPPER
	RET
