/*
 * main.c
 *
 *  Created on: Feb 10, 2017
 *      Author: Charles
 */

#include <stdio.h>
#include "xparameters.h"
#include "xil_types.h"
#include "xstatus.h"
#include "xil_testmem.h"
#include "xil_printf.h"
#include "platform.h"
#include "xtft.h"

static XTft TftInstance;

volatile int *buffer_1 = (int *)(XPAR_MIG_7SERIES_0_BASEADDR + 0x1000000);
volatile int *buffer_2 = (int *)(XPAR_MIG_7SERIES_0_BASEADDR + 0x1400000);
volatile int *start_screen_buffer = (int *)(XPAR_MIG_7SERIES_0_BASEADDR + 0x1800000);
volatile int *end_screen_buffer = (int *)(XPAR_MIG_7SERIES_0_BASEADDR + 0x1A00000);
volatile int *TFT_prt = (int *)XPAR_AXI_TFT_0_BASEADDR;
volatile int *JOYSTICK_prt = (int *)XPAR_JOYSTICK_0_S00_AXI_BASEADDR;
volatile int *RENDER_ptr = (int *)XPAR_HEXAGON_RENDER_0_S00_AXI_BASEADDR;
int *BRAM_CTRL_0_ptr = (int *)(XPAR_AXI_BRAM_CTRL_0_S_AXI_BASEADDR + 4);
int *BRAM_CTRL_1_ptr = (int *)(XPAR_AXI_BRAM_CTRL_1_S_AXI_BASEADDR + 4);
volatile int *Tmr_BaseAddr = (int *)XPAR_TIMER_0_S00_AXI_BASEADDR;

unsigned int random_seed = 532; // this is actually the random number, not just the seed :/
volatile int clock_count;
volatile int Tmr_second;
int level;
int joy_stick_flag = 0;
int joy_stick_counter = 0;


int collision_detection(int cursor, int* lane){
	if (((lane[((cursor + 3) >= 36 ? (cursor - 33) : (cursor + 3)) / 6] & 0x4) != 0) ||
		((lane[((cursor + 2) >= 36 ? (cursor - 34) : (cursor + 2)) / 6] & 0x4) != 0))
		return 1;
	else
		return 0;
}

int main()
{
	init_platform();

	// setup on-screen display
	int Status;
	XTft_Config *TftConfigPtr;
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

	// setup joy-stick
	int i, j, k;
	*(TFT_prt + 1) = 1;
	*JOYSTICK_prt = 164;
	*JOYSTICK_prt = 385;
	*JOYSTICK_prt = 0;

	// setup high score (in tenth of second)
	int current_score;
	int high_score = 0;

	// setup start and end screen
	for (i = 0; i < 480; i++){
		for (j = 0; j < 640; j++){
			*(start_screen_buffer + i*1024 + j) = 0x0;
			*(end_screen_buffer + i*1024 + j) = 0x0;
		}
	}

	for (i = 0; i < 128; i++){
		for (j = 0; j < 16; j++){
//			xil_printf("address = %x\n", address);
			int start_screen_word = *(BRAM_CTRL_0_ptr + i * 16 + j);
//			xil_printf("address = %x\n", address);
			int end_screen_word = *(BRAM_CTRL_1_ptr + i * 16 + j);
//			xil_printf("%d %d %x %x\n", i, j, start_screen_word, end_screen_word);
			for (k = 0; k < 32; k++){
				if (start_screen_word & 0x80000000){
					*(start_screen_buffer + 180288 + i * 1024 + j * 32  + k) = 0xFFFFFFFF;
				}
				start_screen_word = start_screen_word << 1;
				if (end_screen_word & 0x80000000){
					*(end_screen_buffer + 180288 + i * 1024 + j * 32  + k) = 0xFFFFFFFF;
				}
				end_screen_word = end_screen_word << 1;
			}
		}
	}

	// wait for user to start
	*TFT_prt = (int)start_screen_buffer;
	int button_response;
	int button_counter = 0;

	// display levels
	XTft_SetColor(&TftInstance, 0xFFFFFFFF, 0x0);
	TftInstance.TftConfig.VideoMemBaseAddr = (int)start_screen_buffer;
	XTft_SetPos(&TftInstance, 288, 304);
	char* level_text = "Level ";
	for (i = 0; i < 6; i++){
		XTft_Write(&TftInstance, level_text[i]);
	}
	XTft_Write(&TftInstance, level + '0');

	while(1){
		*JOYSTICK_prt = 164;
		*JOYSTICK_prt = 385;
		*JOYSTICK_prt = 0;
		button_response = *(JOYSTICK_prt+1);
		int joy_stick_y = *(JOYSTICK_prt + 2);
		joy_stick_y = (joy_stick_y << 8) | *(JOYSTICK_prt + 3);

//		xil_printf("%d\n", button_response);
		for (i = 0; i < 1000; i++){}
		if(button_response != 0){
			button_counter++;
		}
		if(button_counter == 100){
			*Tmr_BaseAddr = 0; // reset timer
			clock_count = (*Tmr_BaseAddr);
			Tmr_second = *(Tmr_BaseAddr + 1);
			break;
		}

		if (joy_stick_y >= 740) {
			if (joy_stick_flag){
				joy_stick_counter++;
				if (joy_stick_counter == 1000){
					joy_stick_counter = 0;
					if (level < 6){
						level++;
						XTft_SetPos(&TftInstance, 336, 304);
						XTft_Write(&TftInstance, level + '0');
					}
				}
			} else {
				joy_stick_flag = 1;
				joy_stick_counter = 0;
			}

		} else if (joy_stick_y <= 340) {
			if (!joy_stick_flag){
				joy_stick_counter++;
				if (joy_stick_counter == 1000) {
					joy_stick_counter = 0;
					if (level > 0) {
						level--;
						XTft_SetPos(&TftInstance, 336, 304);
						XTft_Write(&TftInstance, level + '0');
					}
				}
			} else {
				joy_stick_flag = 0;
				joy_stick_counter = 0;
			}
		} else {
			joy_stick_counter = 0;
		}
	}

	int pattern;
	int transition;
	int changing_pattern;

	// Start playing
	GAME_START:
	pattern = 0;
	transition = 0;
	changing_pattern = 0;
	int flag = 0;
	int lane[6] = {0};
	int counter[6] = {3, 3, 3, 3, 3, 3};
	int angle = 0;
	int cursor = 0;
	int global_counter = 0;
	int color = 0xF;
	int color_flag = 0;
	int block_speed = 1000;
	int rotation_speed = 1500;
	int color_speed = 1000;
	int refresh_speed = 100;
	int cursor_speed = 100;
	int direction = 1;

	for (i = 0; i < level; i++){
		block_speed /= 1.25;
		rotation_speed /= 1.25;
		cursor_speed /= 1.1;
	}

	// main loop
	while(1){
		// update pattern every 10 seconds
		if ((Tmr_second + 1) % 10 == 0 && !changing_pattern) {
			changing_pattern = 1;
			if (pattern != random_seed % 5){
				pattern = random_seed % 5;
			} else {
				pattern = (random_seed + 1) % 5;
			}
			if (pattern == 0){
				counter[0] = 6;
				counter[1] = 6;
				counter[2] = 6;
				counter[3] = 6;
				counter[4] = 6;
				counter[5] = 6;
			} else if (pattern == 1){
				counter[0] = 6;
				counter[1] = 8;
				counter[2] = 10;
				counter[3] = 6;
				counter[4] = 8;
				counter[5] = 10;
			} else if (pattern == 2){
				counter[0] = 10;
				counter[1] = 8;
				counter[2] = 6;
				counter[3] = 10;
				counter[4] = 8;
				counter[5] = 6;
			} else if (pattern == 3){
				counter[0] = 6;
				counter[1] = 6;
				counter[2] = 6;
				counter[3] = 6;
				counter[4] = 6;
				counter[5] = 6;
			} else if (pattern == 4){
				counter[0] = 6;
				counter[1] = 10;
				counter[2] = 6;
				counter[3] = 10;
				counter[4] = 6;
				counter[5] = 10;
			}
		}

		if (Tmr_second % 10 == 0 && changing_pattern) {
			changing_pattern = 0;
		}

		// update speed every 30 seconds
		if ((Tmr_second + 1) % 30 == 0 && !transition) {
			transition = 1;
			if (level < 6) {
				level++;
				block_speed /= 1.25;
				rotation_speed /= 1.25;
				cursor_speed /= 1.1;
			}
			direction = !direction;
		}

		if (Tmr_second % 30 == 0 && transition) {
			transition = 0;
		}

		// update block positions for each lane
		if (global_counter % block_speed == 0) {
//			xil_printf("counter[i] = %d\n", counter[0]);
			if (pattern == 0) {
				for (i = 0; i < 6; i++) {
					if (counter[i]) {
						if (counter[i] > 0) counter[i]--;
						lane[i] = lane[i] >> 1;
					} else {
						counter[i] = 5;
						lane[i] = lane[i] >> 1;
						if (!transition){
							if ((random_seed % 6) != i) {
								lane[i] = lane[i] | 0x2000;
							}
						}
					}
				}
			} else if (pattern == 1 || pattern == 2) {
				for (i = 0; i < 6; i++) {
					if (counter[i]) {
						if (counter[i] > 0) counter[i]--;
						lane[i] = lane[i] >> 1;
					} else {
						counter[i] = 5;
						if (!transition){
							lane[i] = (lane[i] >> 1) | 0x2000;
						}
					}
				}
			} else if (pattern == 3) {
				for (i = 0; i < 6; i++) {
					if (counter[i]) {
						if (counter[i] > 0) counter[i]--;
						lane[i] = lane[i] >> 1;
					} else {
						counter[i] = 5;
						lane[i] = lane[i] >> 1;
						if (!transition){
							if (((random_seed % 3)) != i && ((random_seed % 3) != (i - 3))) {
								lane[i] = lane[i] | 0x2000;
							}
						}
					}
				}
			} else if (pattern == 4) {
				for (i = 0; i < 6; i++) {
					if (counter[i]) {
						if (counter[i] > 0) counter[i]--;
						lane[i] = lane[i] >> 1;
					} else {
						counter[i] = 8;
						if (!transition){
							lane[i] = (lane[i] >> 1) | 0x2000;
						}
					}
				}
			}

			// collision detection
			if (collision_detection(cursor, lane)){
				if (current_score > high_score)
					high_score = current_score;
				for (i = 0; i < 5000000; i++){} // small delay before end screen
				break;
			}
		}

		// update rotation angle
		if (global_counter % rotation_speed == 0){
			if (direction) {
				angle++;
				if (angle == 36)
					angle = 0;
			} else {
				angle--;
				if (angle == -1)
					angle = 35;
			}
		}

		// update color
		if (global_counter % color_speed == 0) {
			if (color_flag == 0) {
				color++;
				if ((color & 0xF) == 0xF) {
					color_flag = 1;
				}
			} else if (color_flag == 1) {
				color += 0x10;
				if ((color & 0xF0) == 0xF0) {
					color_flag = 2;
				}
			} else if (color_flag == 2) {
				color += 0x100;
				if ((color & 0xF00) == 0xF00) {
					color_flag = 3;
				}
			} else if (color_flag == 3) {
				color--;
				if ((color & 0xF) == 0) {
					color_flag = 4;
				}
			} else if (color_flag == 4) {
				color -= 0x10;
				if ((color & 0xF0) == 0) {
					color_flag = 5;
				}
			} else if (color_flag == 5) {
				color -= 0x100;
				if ((color & 0x100) == 0) {
					color_flag = 0;
				}
			}
		}

		// update cursor position
		*JOYSTICK_prt = 164;
		*JOYSTICK_prt = 385;
		*JOYSTICK_prt = 0;
		int joy_stick_y = *(JOYSTICK_prt + 2);
		joy_stick_y = (joy_stick_y << 8) | *(JOYSTICK_prt + 3);
//		xil_printf("%d\n", joy_stick_y);
		if (joy_stick_y >= 740) {
			if (joy_stick_flag){
				joy_stick_counter++;
				if (joy_stick_counter == cursor_speed){
					joy_stick_counter = 0;
					if(!collision_detection(cursor, lane)) cursor++;
					if (cursor == 36)
						cursor = 0;
				}
			} else {
				joy_stick_flag = 1;
				joy_stick_counter = 0;
			}

		} else if (joy_stick_y <= 340) {
			if (!joy_stick_flag){
				joy_stick_counter++;
				if (joy_stick_counter == cursor_speed) {
					joy_stick_counter = 0;
					if(!collision_detection(cursor, lane)) cursor--;
					if (cursor == -1)
						cursor = 35;
				}
			} else {
				joy_stick_flag = 0;
				joy_stick_counter = 0;
			}
		} else {
			joy_stick_counter = 0;
		}

		// refresh frame
		if (global_counter % refresh_speed == 0) {
			*RENDER_ptr = flag ? (int) buffer_1 : (int) buffer_2;
			*(RENDER_ptr + 3) = lane[0] & (~0x7);
			*(RENDER_ptr + 4) = lane[1] & (~0x7);
			*(RENDER_ptr + 5) = lane[2] & (~0x7);
			*(RENDER_ptr + 6) = lane[3] & (~0x7);
			*(RENDER_ptr + 7) = lane[4] & (~0x7);
			*(RENDER_ptr + 8) = lane[5] & (~0x7);
			*(RENDER_ptr + 9) = angle;
			*(RENDER_ptr + 10) = cursor;
			*(RENDER_ptr + 1) = ((~color) << 12) | color;
			while (!(*(RENDER_ptr + 2))) {
			}
			*TFT_prt = flag ? (int) buffer_1 : (int) buffer_2;
			// read timer
			clock_count = (*Tmr_BaseAddr);
			Tmr_second = *(Tmr_BaseAddr + 1);
			int Tmr_minute = *(Tmr_BaseAddr + 2);
			int ms = clock_count / 100000;
			char s = Tmr_second % 10;
			char ten_s = (Tmr_second / 10 + Tmr_minute * 6) % 10;
			char hundred_s = (Tmr_second / 10 + Tmr_minute * 6) / 10;
			char tenth_s = (ms / 100) % 10;
//			xil_printf("%ms = %d, ten_s = %d, s = %d, tenth_s = %d\n", ms, ten_s, s, tenth_s);
			current_score = tenth_s + 10 * s + 100 * ten_s + 1000 * hundred_s;
			TftInstance.TftConfig.VideoMemBaseAddr = flag ? (int) buffer_1 : (int) buffer_2;
			int pixel_value = ((color & 0xF00) << 10) | ((color & 0xF0) << 6) | ((color & 0xF) << 2);
			XTft_SetColor(&TftInstance, ~pixel_value, pixel_value);
			XTft_SetPos(&TftInstance, 551, 5);
			char* time_text = "Time: ";
			for (i = 0; i < 5; i++){
				XTft_Write(&TftInstance, time_text[i]);
			}
			XTft_Write(&TftInstance, hundred_s + '0');
			XTft_Write(&TftInstance, ten_s + '0');
			XTft_Write(&TftInstance, s + '0');
			XTft_Write(&TftInstance, '.');
			XTft_Write(&TftInstance, tenth_s + '0');
			XTft_Write(&TftInstance, 's');
			flag = !flag;
		}

		// update random number
		random_seed = (random_seed << 1) | (((random_seed & 0x400) >> 10) ^ ((random_seed & 0x1000) >> 12) ^
											((random_seed & 0x2000) >> 13) ^ ((random_seed & 0x8000) >> 15));

		// update global counter
		global_counter++;
		if (global_counter == 1000000){
			global_counter = 0;
		}
	}

	XTft_SetColor(&TftInstance, 0xFFFFFFFF, 0x0);
	TftInstance.TftConfig.VideoMemBaseAddr = (int)end_screen_buffer;
	// display level
	XTft_SetPos(&TftInstance, 288, 304);
	for (i = 0; i < 6; i++){
		XTft_Write(&TftInstance, level_text[i]);
	}
	XTft_Write(&TftInstance, level + '0');
	// display scores
	// current score
	XTft_SetPos(&TftInstance, 288, 354);
	char* current_score_text = "Time: ";
	for (i = 0; i < 6; i++){
		XTft_Write(&TftInstance, current_score_text[i]);
	}
	int current_score_hundred_s = (current_score / 1000) % 10;
	int current_score_ten_s = (current_score / 100) % 10;
	int current_score_s = (current_score / 10) % 10;
	int current_score_tenth_s = current_score % 10;
	XTft_Write(&TftInstance, current_score_hundred_s + '0');
	XTft_Write(&TftInstance, current_score_ten_s + '0');
	XTft_Write(&TftInstance, current_score_s + '0');
	XTft_Write(&TftInstance, '.');
	XTft_Write(&TftInstance, current_score_tenth_s + '0');
	XTft_Write(&TftInstance, 's');
	// high score
	XTft_SetPos(&TftInstance, 248, 370);
	char* high_score_text = "Best Time: ";
	for (i = 0; i < 11; i++){
		XTft_Write(&TftInstance, high_score_text[i]);
	}
	int high_score_hundred_s = (high_score / 1000) % 10;
	int high_score_ten_s = (high_score / 100) % 10;
	int high_score_s = (high_score / 10) % 10;
	int high_score_tenth_s = high_score % 10;
	XTft_Write(&TftInstance, high_score_hundred_s + '0');
	XTft_Write(&TftInstance, high_score_ten_s + '0');
	XTft_Write(&TftInstance, high_score_s + '0');
	XTft_Write(&TftInstance, '.');
	XTft_Write(&TftInstance, high_score_tenth_s + '0');
	XTft_Write(&TftInstance, 's');
	// wait for user to re-start
	*TFT_prt = (int)end_screen_buffer;
	button_counter = 0;
	while (1) {
		*JOYSTICK_prt = 164;
		*JOYSTICK_prt = 385;
		*JOYSTICK_prt = 0;
		button_response = *(JOYSTICK_prt + 1);
		int joy_stick_y = *(JOYSTICK_prt + 2);
		joy_stick_y = (joy_stick_y << 8) | *(JOYSTICK_prt + 3);
		for (i = 0; i < 1000; i++) {
		}
		if (button_response != 0) {
			button_counter++;
		}
		if (button_counter == 100) {
			*Tmr_BaseAddr = 0; // reset timer
			clock_count = (*Tmr_BaseAddr);
			Tmr_second = *(Tmr_BaseAddr + 1);
			goto GAME_START;
		}

		if (joy_stick_y >= 740) {
			if (joy_stick_flag) {
				joy_stick_counter++;
				if (joy_stick_counter == 1000) {
					joy_stick_counter = 0;
					if (level < 6) {
						level++;
						XTft_SetPos(&TftInstance, 336, 304);
						XTft_Write(&TftInstance, level + '0');
					}
				}
			} else {
				joy_stick_flag = 1;
				joy_stick_counter = 0;
			}

		} else if (joy_stick_y <= 340) {
			if (!joy_stick_flag) {
				joy_stick_counter++;
				if (joy_stick_counter == 1000) {
					joy_stick_counter = 0;
					if (level > 0) {
						level--;
						XTft_SetPos(&TftInstance, 336, 304);
						XTft_Write(&TftInstance, level + '0');
					}
				}
			} else {
				joy_stick_flag = 0;
				joy_stick_counter = 0;
			}
		} else {
			joy_stick_counter = 0;
		}
	}

	cleanup_platform();
    return 0;
}


