//go:build amd64 && !purego
// +build amd64,!purego

#include "textflag.h"

#define x X0
#define y X1
#define t0 X2
#define t1 X3
#define t2 X4
#define t3 X5

#define XTMP6 X6
#define IV X8

#include "aesni_macros_amd64.s"

// func encryptBlocksChain(xk *uint32, dst, src []byte, iv *byte)
TEXT ·encryptBlocksChain(SB),NOSPLIT,$0
#define ctx BX
#define ptx DX
#define ptxLen DI

	MOVQ xk+0(FP), AX
	MOVQ dst+8(FP), ctx
	MOVQ src+32(FP), ptx
	MOVQ src_len+40(FP), ptxLen
	MOVQ iv+56(FP), SI

	MOVUPS (SI), IV

loopSrc:
		CMPQ ptxLen, $16
		JB done_sm4
		SUBQ $16, ptxLen

		MOVOU (ptx), t0
		PXOR IV, t0

		PSHUFB flip_mask<>(SB), t0
		PSHUFD $1, t0, t1
		PSHUFD $2, t0, t2
		PSHUFD $3, t0, t3

		XORL CX, CX

loopRound:
			SM4_SINGLE_ROUND(0, AX, CX, x, y, XTMP6, t0, t1, t2, t3)
			SM4_SINGLE_ROUND(1, AX, CX, x, y, XTMP6, t1, t2, t3, t0)
			SM4_SINGLE_ROUND(2, AX, CX, x, y, XTMP6, t2, t3, t0, t1)
			SM4_SINGLE_ROUND(3, AX, CX, x, y, XTMP6, t3, t0, t1, t2)

			ADDL $16, CX
			CMPL CX, $4*32
			JB loopRound

		PALIGNR $4, t3, t3
		PALIGNR $4, t3, t2
		PALIGNR $4, t2, t1
		PALIGNR $4, t1, t0
		PSHUFB flip_mask<>(SB), t0

		MOVOU t0, IV
		MOVOU t0, (ctx)

		LEAQ 16(ptx), ptx
		LEAQ 16(ctx), ctx
	
		JMP loopSrc

done_sm4:
	MOVUPS IV, (SI)
	RET

#undef ctx
#undef ptx
#undef ptxLen

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

// func decryptBlocksChain(xk *uint32, dst, src []byte, iv *byte)
TEXT ·decryptBlocksChain(SB),NOSPLIT,$0
	MOVQ xk+0(FP), AX
	MOVQ dst+8(FP), BX
	MOVQ src+32(FP), DX
	MOVQ src_len+40(FP), DI
	MOVQ iv+56(FP), SI

	LEAQ (DX)(DI*1), DX
	LEAQ (BX)(DI*1), BX

	CMPB ·useAVX2(SB), $1
	JE   avx2Start

	CMPB ·useAVX(SB), $1
	JE   avxCbcSm4Octets

cbcSm4Octets:
	CMPQ DI, $128
	JLE cbcSm4Nibbles
	SUBQ $128, DI
	LEAQ -128(DX), DX
	LEAQ -128(BX), BX

	MOVOU 0(DX), XWORD0
	MOVOU 16(DX), XWORD1
	MOVOU 32(DX), XWORD2
	MOVOU 48(DX), XWORD3
	MOVOU 64(DX), XWORD4
	MOVOU 80(DX), XWORD5
	MOVOU 96(DX), XWORD6
	MOVOU 112(DX), XWORD7

	SM4_8BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3, XWORD4, XWORD5, XWORD6, XWORD7)
	
	PXOR -16(DX), XWORD0
	PXOR 0(DX), XWORD1
	PXOR 16(DX), XWORD2
	PXOR 32(DX), XWORD3
	PXOR 48(DX), XWORD4
	PXOR 64(DX), XWORD5
	PXOR 80(DX), XWORD6
	PXOR 96(DX), XWORD7	

	MOVOU XWORD0, 0(BX)
	MOVOU XWORD1, 16(BX)
	MOVOU XWORD2, 32(BX)
	MOVOU XWORD3, 48(BX)
	MOVOU XWORD4, 64(BX)
	MOVOU XWORD5, 80(BX)
	MOVOU XWORD6, 96(BX)
	MOVOU XWORD7, 112(BX)		

	JMP cbcSm4Octets

cbcSm4Nibbles:
	CMPQ DI, $64
	JLE cbCSm4Single
	SUBQ $64, DI
	LEAQ -64(DX), DX
	LEAQ -64(BX), BX

	MOVOU 0(DX), XWORD0
	MOVOU 16(DX), XWORD1
	MOVOU 32(DX), XWORD2
	MOVOU 48(DX), XWORD3

	SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)

	PXOR -16(DX), XWORD0
	PXOR 0(DX), XWORD1
	PXOR 16(DX), XWORD2
	PXOR 32(DX), XWORD3

	MOVUPS XWORD0, 0(BX)
	MOVUPS XWORD1, 16(BX)
	MOVUPS XWORD2, 32(BX)
	MOVUPS XWORD3, 48(BX)

cbCSm4Single:
	CMPQ DI, $16
	JEQ cbcSm4Single16

	CMPQ DI, $32
	JEQ cbcSm4Single32

	CMPQ DI, $48
	JEQ cbcSm4Single48

	MOVOU -64(DX), XWORD0
	MOVOU -48(DX), XWORD1
	MOVOU -32(DX), XWORD2
	MOVOU -16(DX), XWORD3

	SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)

	PXOR 0(SI), XWORD0
	PXOR -64(DX), XWORD1
	PXOR -48(DX), XWORD2
	PXOR -32(DX), XWORD3

	MOVUPS XWORD0, -64(BX)
	MOVUPS XWORD1, -48(BX)
	MOVUPS XWORD2, -32(BX)
	MOVUPS XWORD3, -16(BX)
	JMP cbcSm4Done

cbcSm4Single16:
	MOVOU -16(DX), XWORD0

	SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)

	PXOR 0(SI), XWORD0

	MOVUPS XWORD0, -16(BX)
	JMP cbcSm4Done

cbcSm4Single32:
	MOVOU -32(DX), XWORD0
	MOVOU -16(DX), XWORD1

	SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)

	PXOR 0(SI), XWORD0
	PXOR -32(DX), XWORD1

	MOVUPS XWORD0, -32(BX)
	MOVUPS XWORD1, -16(BX)
	JMP cbcSm4Done

cbcSm4Single48:
	MOVOU -48(DX), XWORD0
	MOVOU -32(DX), XWORD1
	MOVOU -16(DX), XWORD2

	SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)

	PXOR 0(SI), XWORD0
	PXOR -48(DX), XWORD1
	PXOR -32(DX), XWORD2

	MOVUPS XWORD0, -48(BX)
	MOVUPS XWORD1, -32(BX)
	MOVUPS XWORD2, -16(BX)
	
cbcSm4Done:
	RET

avxCbcSm4Octets:
	CMPQ DI, $128
	JLE avxCbcSm4Nibbles
	SUBQ $128, DI
	LEAQ -128(DX), DX
	LEAQ -128(BX), BX

	VMOVDQU 0(DX), XWORD0
	VMOVDQU 16(DX), XWORD1
	VMOVDQU 32(DX), XWORD2
	VMOVDQU 48(DX), XWORD3
	VMOVDQU 64(DX), XWORD4
	VMOVDQU 80(DX), XWORD5
	VMOVDQU 96(DX), XWORD6
	VMOVDQU 112(DX), XWORD7

	AVX_SM4_8BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3, XWORD4, XWORD5, XWORD6, XWORD7)
	
	VPXOR -16(DX), XWORD0, XWORD0
	VPXOR 0(DX), XWORD1, XWORD1
	VPXOR 16(DX), XWORD2, XWORD2
	VPXOR 32(DX), XWORD3, XWORD3
	VPXOR 48(DX), XWORD4, XWORD4
	VPXOR 64(DX), XWORD5, XWORD5
	VPXOR 80(DX), XWORD6, XWORD6
	VPXOR 96(DX), XWORD7, XWORD7

	VMOVDQU XWORD0, 0(BX)
	VMOVDQU XWORD1, 16(BX)
	VMOVDQU XWORD2, 32(BX)
	VMOVDQU XWORD3, 48(BX)
	VMOVDQU XWORD4, 64(BX)
	VMOVDQU XWORD5, 80(BX)
	VMOVDQU XWORD6, 96(BX)
	VMOVDQU XWORD7, 112(BX)	

	JMP avxCbcSm4Octets

avxCbcSm4Nibbles:
	CMPQ DI, $64
	JLE avxCbCSm4Single
	SUBQ $64, DI
	LEAQ -64(DX), DX
	LEAQ -64(BX), BX

	VMOVDQU 0(DX), XWORD0
	VMOVDQU 16(DX), XWORD1
	VMOVDQU 32(DX), XWORD2
	VMOVDQU 48(DX), XWORD3

	AVX_SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)

	VPXOR -16(DX), XWORD0, XWORD0
	VPXOR 0(DX), XWORD1, XWORD1
	VPXOR 16(DX), XWORD2, XWORD2
	VPXOR 32(DX), XWORD3, XWORD3

	VMOVDQU XWORD0, 0(BX)
	VMOVDQU XWORD1, 16(BX)
	VMOVDQU XWORD2, 32(BX)
	VMOVDQU XWORD3, 48(BX)

avxCbCSm4Single:
	CMPQ DI, $16
	JEQ avxCbcSm4Single16

	CMPQ DI, $32
	JEQ avxCbcSm4Single32

	CMPQ DI, $48
	JEQ avxCbcSm4Single48

	VMOVDQU -64(DX), XWORD0
	VMOVDQU -48(DX), XWORD1
	VMOVDQU -32(DX), XWORD2
	VMOVDQU -16(DX), XWORD3

	AVX_SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)

	VPXOR 0(SI), XWORD0, XWORD0
	VPXOR -64(DX), XWORD1, XWORD1
	VPXOR -48(DX), XWORD2, XWORD2
	VPXOR -32(DX), XWORD3, XWORD3

	VMOVDQU XWORD0, -64(BX)
	VMOVDQU XWORD1, -48(BX)
	VMOVDQU XWORD2, -32(BX)
	VMOVDQU XWORD3, -16(BX)
	JMP avxCbcSm4Done

avxCbcSm4Single16:
	VMOVDQU -16(DX), XWORD0

	AVX_SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)

	VPXOR 0(SI), XWORD0, XWORD0

	VMOVDQU XWORD0, -16(BX)
	JMP avxCbcSm4Done

avxCbcSm4Single32:
	VMOVDQU -32(DX), XWORD0
	VMOVDQU -16(DX), XWORD1

	AVX_SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)

	VPXOR 0(SI), XWORD0, XWORD0
	VPXOR -32(DX), XWORD1, XWORD1

	VMOVDQU XWORD0, -32(BX)
	VMOVDQU XWORD1, -16(BX)
	JMP avxCbcSm4Done

avxCbcSm4Single48:
	VMOVDQU -48(DX), XWORD0
	VMOVDQU -32(DX), XWORD1
	VMOVDQU -16(DX), XWORD2

	AVX_SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)

	VPXOR 0(SI), XWORD0, XWORD0
	VPXOR -48(DX), XWORD1, XWORD1
	VPXOR -32(DX), XWORD2, XWORD2

	VMOVDQU XWORD0, -48(BX)
	VMOVDQU XWORD1, -32(BX)
	VMOVDQU XWORD2, -16(BX)
	
avxCbcSm4Done:
	RET

avx2Start:
	VBROADCASTI128 nibble_mask<>(SB), NIBBLE_MASK
	VBROADCASTI128 flip_mask<>(SB), BYTE_FLIP_MASK
	VBROADCASTI128 bswap_mask<>(SB), BSWAP_MASK

avx2_16blocks:
	CMPQ DI, $256
	JLE avx2CbcSm4Octets
	SUBQ $256, DI
	LEAQ -256(DX), DX
	LEAQ -256(BX), BX

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

	VPXOR -16(DX), XDWORD0, XDWORD0
	VPXOR 16(DX), XDWORD1, XDWORD1
	VPXOR 48(DX), XDWORD2, XDWORD2
	VPXOR 80(DX), XDWORD3, XDWORD3
	VPXOR 112(DX), XDWORD4, XDWORD4
	VPXOR 144(DX), XDWORD5, XDWORD5
	VPXOR 176(DX), XDWORD6, XDWORD6
	VPXOR 208(DX), XDWORD7, XDWORD7

	VMOVDQU XDWORD0, 0(BX)
	VMOVDQU XDWORD1, 32(BX)
	VMOVDQU XDWORD2, 64(BX)
	VMOVDQU XDWORD3, 96(BX)
	VMOVDQU XDWORD4, 128(BX)
	VMOVDQU XDWORD5, 160(BX)
	VMOVDQU XDWORD6, 192(BX)
	VMOVDQU XDWORD7, 224(BX)

	JMP avx2_16blocks

avx2CbcSm4Octets:
	CMPQ DI, $128
	JLE avx2CbcSm4Nibbles
	SUBQ $128, DI
	LEAQ -128(DX), DX
	LEAQ -128(BX), BX

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
	
	VPXOR -16(DX), XDWORD0, XDWORD0
	VPXOR 16(DX), XDWORD1, XDWORD1
	VPXOR 48(DX), XDWORD2, XDWORD2
	VPXOR 80(DX), XDWORD3, XDWORD3

	VMOVDQU XDWORD0, 0(BX)
	VMOVDQU XDWORD1, 32(BX)
	VMOVDQU XDWORD2, 64(BX)
	VMOVDQU XDWORD3, 96(BX)

	JMP avx2CbcSm4Octets

avx2CbcSm4Nibbles:
	CMPQ DI, $64
	JLE avx2CbCSm4Single
	SUBQ $64, DI
	LEAQ -64(DX), DX
	LEAQ -64(BX), BX

	VMOVDQU 0(DX), XWORD0
	VMOVDQU 16(DX), XWORD1
	VMOVDQU 32(DX), XWORD2
	VMOVDQU 48(DX), XWORD3

	AVX_SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)

	VPXOR -16(DX), XWORD0, XWORD0
	VPXOR 0(DX), XWORD1, XWORD1
	VPXOR 16(DX), XWORD2, XWORD2
	VPXOR 32(DX), XWORD3, XWORD3

	VMOVDQU XWORD0, 0(BX)
	VMOVDQU XWORD1, 16(BX)
	VMOVDQU XWORD2, 32(BX)
	VMOVDQU XWORD3, 48(BX)

avx2CbCSm4Single:
	CMPQ DI, $16
	JEQ avx2CbcSm4Single16

	CMPQ DI, $32
	JEQ avx2CbcSm4Single32

	CMPQ DI, $48
	JEQ avx2CbcSm4Single48

	VMOVDQU -64(DX), XWORD0
	VMOVDQU -48(DX), XWORD1
	VMOVDQU -32(DX), XWORD2
	VMOVDQU -16(DX), XWORD3

	AVX_SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)

	VPXOR 0(SI), XWORD0, XWORD0
	VPXOR -64(DX), XWORD1, XWORD1
	VPXOR -48(DX), XWORD2, XWORD2
	VPXOR -32(DX), XWORD3, XWORD3

	VMOVDQU XWORD0, -64(BX)
	VMOVDQU XWORD1, -48(BX)
	VMOVDQU XWORD2, -32(BX)
	VMOVDQU XWORD3, -16(BX)
	JMP avx2CbcSm4Done

avx2CbcSm4Single16:
	VMOVDQU -16(DX), XWORD0

	AVX_SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)

	VPXOR 0(SI), XWORD0, XWORD0

	VMOVDQU XWORD0, -16(BX)
	JMP avx2CbcSm4Done

avx2CbcSm4Single32:
	VMOVDQU -32(DX), XWORD0
	VMOVDQU -16(DX), XWORD1

	AVX_SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)

	VPXOR 0(SI), XWORD0, XWORD0
	VPXOR -32(DX), XWORD1, XWORD1

	VMOVDQU XWORD0, -32(BX)
	VMOVDQU XWORD1, -16(BX)
	JMP avx2CbcSm4Done

avx2CbcSm4Single48:
	VMOVDQU -48(DX), XWORD0
	VMOVDQU -32(DX), XWORD1
	VMOVDQU -16(DX), XWORD2

	AVX_SM4_4BLOCKS(AX, XWORD, YWORD, XWTMP0, XWTMP1, XWORD0, XWORD1, XWORD2, XWORD3)

	VPXOR 0(SI), XWORD0, XWORD0
	VPXOR -48(DX), XWORD1, XWORD1
	VPXOR -32(DX), XWORD2, XWORD2

	VMOVDQU XWORD0, -48(BX)
	VMOVDQU XWORD1, -32(BX)
	VMOVDQU XWORD2, -16(BX)
	
avx2CbcSm4Done:
	VZEROUPPER
	RET
