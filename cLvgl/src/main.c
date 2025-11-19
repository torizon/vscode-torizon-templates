/*******************************************************************
 *
 * main.c - LVGL example application using LVGL on Unix-like
 * operating systems.
 *
 * Based on lv_port_linux/main.c
 *
 * Copyright (c) 2024 LVGL LLC.
 *
 * Authors:
 * LVGL LLC, gabriel.catel@edgemtech.ch
 * LVGL LLC, erik.tagirov@edgemtech.ch
 *
 ******************************************************************/
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>

#include "lvgl/lvgl.h"
#include "lvgl/demos/lv_demos.h"

#define FRAME_BUFFER_DEV "/dev/fb0"

static void lv_linux_disp_init(void)
{
    const char *device = FRAME_BUFFER_DEV;
    lv_display_t * disp = lv_linux_fbdev_create();

    lv_linux_fbdev_set_file(disp, device);
}

static void lv_linux_run_loop(void)
{
    uint32_t time_till_next_ms;

    /*Handle LVGL tasks*/
    while(1) {
        time_till_next_ms = lv_timer_handler();
        usleep(time_till_next_ms * 1000);
    }
}

int main(int argc, char **argv)
{

    /* Initialize LVGL. */
    lv_init();

    /* Initialize the configured backend */
    lv_linux_disp_init();

    /*Create a Demo*/
    lv_demo_widgets();
    lv_demo_widgets_start_slideshow();

    /* Print a message, used in automated tests */
    printf("Hello Torizon\n");
    fflush(stdout);

    lv_linux_run_loop();

    return 0;
}
