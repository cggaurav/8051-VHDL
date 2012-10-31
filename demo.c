#include <REG51.H>

sbit led1 = P2^0;
sbit switch_input1 = P1^0;
sbit switch_input2 = P3^0;
sbit led2 = P2^1;
sbit led3 = P2^2;
sbit led4 = P2^3;

void blink();
void delay(unsigned char x);

void main() {
// 	unsigned char push_B, push_A;
// 	unsigned long count, i;
	unsigned char i, j;
	unsigned char data x;
	
	x = 0x00;
	while(1) {
		if(!switch_input1 && !switch_input2) {
			blink();
		}
		
		while(switch_input1) {
			if(x == 0x10) {
				for(j=0; j<3; j++) {
					blink();
				}
				x = 0x00;			
			}
			P2 = x;
			for(i=1000; i>0; i--);
			x++;
		}

 	}

}

void delay(unsigned char x) {
	unsigned char i;
	for(i=x; i>0; i--);
}

void blink() {
	unsigned char i;
	led1 = 1;
	led2 = 1;
	led3 = 1;
	led4 = 1;
	for(i=200; i>0; i--);
	led1 = 0;
	led2 = 0;
	led3 = 0;
	led4 = 0;
}

