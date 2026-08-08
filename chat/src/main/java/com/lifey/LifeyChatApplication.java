package com.lifey;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * The trainer↔client chat, as its own deployable
 * (docs/chat/44-chat-service-extraction-plan.md).
 *
 * <p>{@code @EnableScheduling} for one job: {@code ChatUnreadReminderJob}. It
 * runs every five minutes and <b>must not run twice</b>, which is the reason
 * this service is deployed as a single instance — see §6.4 for what to do if
 * that ever stops being true.
 */
@SpringBootApplication
@EnableScheduling
public class LifeyChatApplication {

    public static void main(String[] args) {
        SpringApplication.run(LifeyChatApplication.class, args);
    }
}
