#include "gd32vf103.h"
#include "board/gd32vf103r_start.h"
#include "systick.h"

void led_init(void);

int main(void)
{  
    led_init();
    
    while(1){
        gpio_bit_set(GPIOA, GPIO_PIN_7);
        delay_1ms(500);
        gpio_bit_reset(GPIOA, GPIO_PIN_7);
        delay_1ms(500);
    }
}

void led_init(void)
{
   rcu_periph_clock_enable(RCU_GPIOA);
   gpio_init(GPIOA, GPIO_MODE_OUT_PP, GPIO_OSPEED_50MHZ, GPIO_PIN_7);
   gpio_bit_reset(GPIOA, GPIO_PIN_7);
}
