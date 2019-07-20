#include "setup.h"
#include "s3c2440_soc.h"

#define PCLK            50000000    // init.c中的clock_init函数设置PCLK为50MHz
#define UART_CLK        PCLK        //  UART0的时钟源设为PCLK
#define UART_BAUD_RATE  115200      // 波特率
#define UART_BRD        ((UART_CLK  / (UART_BAUD_RATE * 16)) - 1)
#define TXD0READY       (1<<2)

void uart0_init(void);
void putc(unsigned char c);
void puts(char *str);

int main(void){

    /* 1. Init Uart, print logs when boot kernel */
    uart0_init();

    /* 2. move kernel into soc inside memory */
    puts("moving kernel from nand into memory...\r\n");
    nand_read(0x60000+64, (unsigned char *)0x30008000, 0x200000);    //from 0x60000+64 to 0x30008000

    /* 3. set boot params, to be parsed by kenel when booting */
    puts("Set boot params....\n\r");
	setup_start_tag();
	setup_memory_tags();
	setup_commandline_tag("noinitrd root=/dev/mtdblock3 init=/linuxrc console=ttySAC0");
	setup_end_tag();

    /* 4. jump and boot kernal */
    puts("Boot kernel...\r\n");
    void (*theKernel)(int zero, int arch, unsigned int params);
	volatile unsigned int *p = (volatile unsigned int *)0x30008000;
	theKernel = (void (*)(int, int, unsigned int))0x30008000;
	theKernel(0, 362, 0x30000100);  


    puts("oh no!!! error broken in main !!\r\n"); //if program runs normally, wouldn't come to here

    return -1;    // if run to here , some error happens
}


/*
 * 初始化UART0
 * 115200,8N1,无流控
 */
void uart0_init(void)
{
    GPHCON  |= 0xa0;    // GPH2,GPH3用作TXD0,RXD0
    GPHUP   = 0x0c;     // GPH2,GPH3内部上拉

    ULCON0  = 0x03;     // 8N1(8个数据位，无较验，1个停止位)
    UCON0   = 0x05;     // 查询方式，UART时钟源为PCLK
    UFCON0  = 0x00;     // 不使用FIFO
    UMCON0  = 0x00;     // 不使用流控
    UBRDIV0 = UART_BRD; // 波特率为115200
}
/*
 * 发送一个字符
 */
void putc(unsigned char c)
{
    /* 等待，直到发送缓冲区中的数据已经全部发送出去 */
    while (!(UTRSTAT0 & TXD0READY));
    
    /* 向UTXH0寄存器中写入数据，UART即自动将它发送出去 */
    UTXH0 = c;
}

void puts(char *str)
{
	int i = 0;
	while (str[i])
	{
		putc(str[i]);
		i++;
	}
}