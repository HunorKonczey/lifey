package com.lifey;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class LifeyApplication {

    public static void main(String[] args) {
        SpringApplication.run(LifeyApplication.class, args);
    }
}
