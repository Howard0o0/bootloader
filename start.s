#define WTCON                               0x53000000
#define MPLLCON                             0x4C000004
#define S3C2440_FCLK_400MHz                 ((0x5c<<12)|(0x01<<4)|(0x01))
#define CLKDIVN                             0x4C000014
#define DIVN_UPLL_0_HDIVN_4_PDIVN_2         ((0<<3)|(2<<1)|(1))
#define MEM_CTL_BASE                        0x48000000

.text
.global _start
_start:

/* 1. close the Watch Dog */
    ldr r0,=WTCON
    mv  r1,#0
    str r1,[r0]

/* 2. config clock */
    // set FCLK = 400MHZ
    ldr r0,=MPLLCON
    ldr r1,=S3C2440_FCLK_400MHz   // S3C2440_FCLK_400MHz is not an "immediate-digit", can't use MOV
    str r1,[r0]

    // HDIVN=4 , PDIV=2   =>  HCLK=100MHz , PCLK=50MHz
    ldr r0,=CLKDIVN
    ldr r1,=DIVN_UPLL_0_HDIVN_4_PDIVN_2
    str r1,[r0]
  
    // If HDIVN is not 0, the CPU bus mode has to be changed from the fast bus mode to the asynchronous bus mode using following instructions(S3C2440 does not support synchronous bus mode)
    mrc p15,0,r0,c1,c0,0
    orr r0,r0,#R1_nF:OR:R1_iA
    mcr p15,0,r0,c1,c0,0

    /* enable ICACHE */
	mrc p15, 0, r0, c1, c0, 0	@ read control reg
	orr r0, r0, #(1<<12)
	mcr	p15, 0, r0, c1, c0, 0   @ write it back

/* 3. init SDRAM */
    ldr r0,=MEM_CTL_BASE
    adr r1,sdram_config
    add r3,r0,#(13*4)   //r3 = last MEM_CTL_Register
sdram_config_loop:
    ldr r2,[r1],#4      // ldr r2,[r1] then r1=r1+4 ; r2 is a buffer
    str r2,[r0],#4      // r0 = r0 + 4
    cmp r0,r3           // if r0 != r3 , keep configuring sdram
    bne sdram_config_loop

/* 4. relocation : 把bootloader本身的代码从flash复制到它的链接地址去 !!!!需要回顾第一期视频!!!!*/
    ldr sp, =0x34000000

	bl nand_init   // cal nand_init() in C

	mov r0, #0
	ldr r1, =_start
	ldr r2, =__bss_start
	sub r2, r2, r1
	
	bl copy_code_to_sdram
	bl clear_bss

/* 5. jump to main */
    ldr lr,=halt    // if main return, jump to halt
    ldr pc,=main
halt:
    b halt


sdram_config:  // 13 regesters to config
	.long 0x22011110	 //BWSCON
	.long 0x00000700	 //BANKCON0
	.long 0x00000700	 //BANKCON1
	.long 0x00000700	 //BANKCON2
	.long 0x00000700	 //BANKCON3  
	.long 0x00000700	 //BANKCON4
	.long 0x00000700	 //BANKCON5
	.long 0x00018005	 //BANKCON6
	.long 0x00018005	 //BANKCON7
	.long 0x008C04F4	 // REFRESH
	.long 0x000000B1	 //BANKSIZE
	.long 0x00000030	 //MRSRB6
	.long 0x00000030	 //MRSRB7