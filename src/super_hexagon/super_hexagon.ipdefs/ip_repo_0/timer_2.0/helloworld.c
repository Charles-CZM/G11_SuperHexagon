#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xio.h"
#include "xtft.h"
#include "xparameters.h"


#define TFT_DEVICE_ID XPAR_XPS_TFT_0_DEVICE_ID

static XTft TftInstance;

volatile unsigned int *TFT_BaseAddr = (volatile unsigned int*)XPAR_AXI_TFT_0_BASEADDR;
volatile unsigned int *DDR_BaseAddr = (volatile unsigned int*)XPAR_MIG7SERIES_0_BASEADDR;
//volatile unsigned int *JST_BaseAddr = (volatile unsigned int *)XPAR_JOYSTICK_0_S00_AXI_BASEADDR;
volatile unsigned int *Tmr_BaseAddr = (volatile unsigned int *)XPAR_TIMER_0_S00_AXI_BASEADDR;

#define x_boundry_left	 	259
#define x_boundry_right	 	379
#define y_boundry_top	 	179
#define y_boundry_bottom 	299

#define counter_boundry_x  	120
#define counter_boundry_y   120

void show(unsigned int);

int main()
{
    init_platform();

    *(TFT_BaseAddr + 1) = 1;
    uint8_t red = 11;
    uint8_t green = 1;
    uint8_t blue = 3;

    unsigned int color = (red << 18)|(green << 10)|(blue << 2);
    //unsigned int timer = *Tmr_BaseAddr;
    int i, j;

    int Status;
    XTft_Config *TftConfigPtr;

    /*
    int birth_y = 179;
    int birth_x= 259;

    int input_prev = -1;
    int input_curr;

    int move_counter_x = 0;
    int move_counter_y = 0;

    short line_1 = 0;
    short line_2 = 0;
    short line_3 = 0;
    short line_4 = 0;
	*/

    TftConfigPtr = XTft_LookupConfig( XPAR_AXI_TFT_0_DEVICE_ID);

	if (TftConfigPtr == (XTft_Config *)NULL) {
		//return XST_FAILURE;
		return 0;
	}

	Status = XTft_CfgInitialize(&TftInstance, TftConfigPtr, TftConfigPtr->BaseAddress);
	if (Status != XST_SUCCESS) {
		//return XST_FAILURE;
		return 0;
	}

    XTft_SetColor(&TftInstance, 0x0fffffff,0x000000);
    XTft_SetPos(&TftInstance, 319,0);

    //TftInstance.BgColor= color;
	//XTft_Write(&TftInstance,'D');
	//XTft_Write(&TftInstance,'O');
	//XTft_Write(&TftInstance,'N');
	//XTft_Write(&TftInstance,'E');

    print("Start Render\n\r");

    for(i = 10; i < 480; i++){
		for(j = 0; j < 640; j++){
			if( i == 189 && j >= 269 && j <= 369)
				*(DDR_BaseAddr + i*1024 + j) = color;
			else if( i == 289 && j >= 269 && j <= 369)
				*(DDR_BaseAddr + i*1024 + j) = color;
			else if( j == 269 && i >= 189 && i <= 289)
				*(DDR_BaseAddr + i*1024 + j) = color;
			else if( j == 369 && i >= 189 && i <= 289)
				*(DDR_BaseAddr + i*1024 + j) = color;
			else
				*(DDR_BaseAddr + i*1024 + j) = blue << 2;
		}
    }

    //*(JST_BaseAddr) = 164;
    //*(JST_BaseAddr) = 385;
    //*(JST_BaseAddr) = 0;
    //int offset;
    unsigned int second;
    unsigned int minute;
    char min_tmp = ' ';
    char sec_tmp = ' ';
    while(1){
    	second = *(Tmr_BaseAddr + 1);
    	minute = *(Tmr_BaseAddr + 2);
    	//XTft_SetColor(&TftInstance, 0x0fffffff,0x000000);
    	XTft_SetPos(&TftInstance, 289,0);

    	if(minute < 10){
    			min_tmp = minute + '0';
        		XTft_Write(&TftInstance,'0');
        		XTft_Write(&TftInstance,min_tmp);
        	}
        	else
        		show(minute);

    	XTft_Write(&TftInstance,':');

    	if(second < 10){
    		sec_tmp = second + '0';
    		XTft_Write(&TftInstance,'0');
    		XTft_Write(&TftInstance,sec_tmp);
    	}
    	else
    		show(second);

    	/**(JST_BaseAddr) = 164;
		*(JST_BaseAddr) = 385;
		*(JST_BaseAddr) = 0;
		input_curr = *(JST_BaseAddr + 3);
		//x = (*(JST_BaseAddr + 1)) >> 2;
		if(input_curr != input_prev){
			if(input_curr > input_prev){

				if(((birth_x + move_counter_x) == x_boundry_right) && (birth_y + move_counter_y == y_boundry_top)){
					//move_counter_x ++;
					line_2 = 1;
					line_1 = 0;
					line_3 = 0;
					line_4 = 0;
				}
				else if(((birth_x + move_counter_x) == x_boundry_left) && (birth_y + move_counter_y == y_boundry_top)){
					//move_counter_x --;
					line_1 = 1;
					line_2 = 0;
					line_3 = 0;
					line_4 = 0;
				}
				else if (((birth_y + move_counter_y) == y_boundry_bottom) && ((birth_x + move_counter_x) == x_boundry_right)){
					//move_counter_y++;
					line_3 = 1;
					line_1 = 0;
					line_2 = 0;
					line_4 = 0;
				}
				else if((birth_y + move_counter_y == y_boundry_bottom) && ((birth_x + move_counter_x) == x_boundry_left)){
					line_4 = 1;
					line_1 = 0;
					line_2 = 0;
					line_3 = 0;
				}

				if(line_1){
					move_counter_x++;
					//draw
					*(DDR_BaseAddr + (birth_y + move_counter_y)*1024 + birth_x + move_counter_x) = color;
					//*(DDR_BaseAddr + (birth_y + move_counter_y)*1024 + birth_x + move_counter_x + 1) = color;
					//*(DDR_BaseAddr + (birth_y + move_counter_y + 1)*1024 + birth_x + move_counter_x) = color;
					//*(DDR_BaseAddr + (birth_y + move_counter_y + 1)*1024 + birth_x + move_counter_x + 1) = color;
				}
				else if(line_2){
					move_counter_y++;
					*(DDR_BaseAddr + (birth_y + move_counter_y)*1024 + birth_x + move_counter_x) = color;
					//*(DDR_BaseAddr + (birth_y + move_counter_y)*1024 + birth_x + move_counter_x + 1) = color;
					//*(DDR_BaseAddr + (birth_y + move_counter_y + 1)*1024 + birth_x + move_counter_x) = color;
					//*(DDR_BaseAddr + (birth_y + move_counter_y + 1)*1024 + birth_x + move_counter_x + 1) = color;
				}
				else if(line_3){
					move_counter_x--;
					*(DDR_BaseAddr + (birth_y + move_counter_y)*1024 + birth_x + move_counter_x) = color;
					//*(DDR_BaseAddr + (birth_y + move_counter_y)*1024 + birth_x + move_counter_x + 1) = color;
					//*(DDR_BaseAddr + (birth_y + move_counter_y + 1)*1024 + birth_x + move_counter_x) = color;
					//*(DDR_BaseAddr + (birth_y + move_counter_y + 1)*1024 + birth_x + move_counter_x + 1) = color;
				}
				else if(line_4){
					move_counter_y--;
					*(DDR_BaseAddr + (birth_y + move_counter_y)*1024 + birth_x + move_counter_x) = color;
					//*(DDR_BaseAddr + (birth_y + move_counter_y)*1024 + birth_x + move_counter_x + 1) = color;
					//*(DDR_BaseAddr + (birth_y + move_counter_y + 1)*1024 + birth_x + move_counter_x) = color;
					//*(DDR_BaseAddr + (birth_y + move_counter_y + 1)*1024 + birth_x + move_counter_x + 1) = color;
				}
			}
			else if(input_curr < input_prev){
				if(((birth_x + move_counter_x) == x_boundry_right) && (birth_y + move_counter_y == y_boundry_top)){
					//move_counter_x ++;
					line_2 = 0;
					line_1 = 1;
					line_3 = 0;
					line_4 = 0;
				}
				else if(((birth_x + move_counter_x) == x_boundry_left) && (birth_y + move_counter_y == y_boundry_top)){
					//move_counter_x --;
					line_1 = 0;
					line_2 = 0;
					line_3 = 0;
					line_4 = 1;
				}
				else if (((birth_y + move_counter_y) == y_boundry_bottom) && ((birth_x + move_counter_x) == x_boundry_right)){
					//move_counter_y++;
					line_3 = 0;
					line_1 = 0;
					line_2 = 1;
					line_4 = 0;
				}
				else if((birth_y + move_counter_y == y_boundry_bottom) && ((birth_x + move_counter_x) == x_boundry_left)){
					line_4 = 0;
					line_1 = 0;
					line_2 = 0;
					line_3 = 1;
				}

				if(line_1){
					move_counter_x--;
					//draw
					*(DDR_BaseAddr + (birth_y + move_counter_y)*1024 + birth_x + move_counter_x) = color;
					//*(DDR_BaseAddr + (birth_y + move_counter_y)*1024 + birth_x + move_counter_x + 1) = color;
					//*(DDR_BaseAddr + (birth_y + move_counter_y + 1)*1024 + birth_x + move_counter_x) = color;
					//*(DDR_BaseAddr + (birth_y + move_counter_y + 1)*1024 + birth_x + move_counter_x + 1) = color;
				}
				else if(line_2){
					move_counter_y--;
					*(DDR_BaseAddr + (birth_y + move_counter_y)*1024 + birth_x + move_counter_x) = color;
					//*(DDR_BaseAddr + (birth_y + move_counter_y)*1024 + birth_x + move_counter_x + 1) = color;
					//*(DDR_BaseAddr + (birth_y + move_counter_y + 1)*1024 + birth_x + move_counter_x) = color;
					//*(DDR_BaseAddr + (birth_y + move_counter_y + 1)*1024 + birth_x + move_counter_x + 1) = color;
				}
				else if(line_3){
					move_counter_x++;
					*(DDR_BaseAddr + (birth_y + move_counter_y)*1024 + birth_x + move_counter_x) = color;
					//*(DDR_BaseAddr + (birth_y + move_counter_y)*1024 + birth_x + move_counter_x + 1) = color;
					//*(DDR_BaseAddr + (birth_y + move_counter_y + 1)*1024 + birth_x + move_counter_x) = color;
					//*(DDR_BaseAddr + (birth_y + move_counter_y + 1)*1024 + birth_x + move_counter_x + 1) = color;
				}
				else if(line_4){
					move_counter_y++;
					*(DDR_BaseAddr + (birth_y + move_counter_y)*1024 + birth_x + move_counter_x) = color;
					//*(DDR_BaseAddr + (birth_y + move_counter_y)*1024 + birth_x + move_counter_x + 1) = color;
					//*(DDR_BaseAddr + (birth_y + move_counter_y + 1)*1024 + birth_x + move_counter_x) = color;
					//*(DDR_BaseAddr + (birth_y + move_counter_y + 1)*1024 + birth_x + move_counter_x + 1) = color;
				}

			}
		}

		input_prev = input_curr;*/

    }

    cleanup_platform();
    return 0;
}

void show(unsigned int number){
	char tmp;

	if(number != 0){
		tmp = number%10 + '0';
		number = number/10;
		show(number);
		XTft_Write(&TftInstance,tmp);

	}

}
