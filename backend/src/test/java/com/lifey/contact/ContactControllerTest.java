package com.lifey.contact;

import com.lifey.mail.MailLanguage;
import com.lifey.mail.service.MailService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(ContactController.class)
class ContactControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    MailService mailService;

    @Test
    void submit_valid_sendsAndReturnsNoContent() throws Exception {
        mockMvc.perform(post("/api/v1/contact").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Szabó Anna","email":"anna@example.com","message":"Kérdésem lenne az árakról.","locale":"hu"}
                                """))
                .andExpect(status().isNoContent());

        verify(mailService).sendContactMessage(
                eq("Szabó Anna"), eq("anna@example.com"), eq("Kérdésem lenne az árakról."), eq(MailLanguage.HU));
    }

    @Test
    void submit_unknownLocale_fallsBackToEnglish() throws Exception {
        mockMvc.perform(post("/api/v1/contact").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Anna","email":"anna@example.com","message":"Hi there."}
                                """))
                .andExpect(status().isNoContent());

        verify(mailService).sendContactMessage(eq("Anna"), eq("anna@example.com"), eq("Hi there."), eq(MailLanguage.EN));
    }

    @Test
    void submit_blankEmail_rejectedBeforeSending() throws Exception {
        mockMvc.perform(post("/api/v1/contact").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Anna","email":"","message":"Hi there."}
                                """))
                .andExpect(status().isBadRequest());

        verifyNoInteractions(mailService);
    }

    @Test
    void submit_malformedEmail_rejected() throws Exception {
        mockMvc.perform(post("/api/v1/contact").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Anna","email":"not-an-email","message":"Hi there."}
                                """))
                .andExpect(status().isBadRequest());

        verifyNoInteractions(mailService);
    }

    @Test
    void submit_blankMessage_rejected() throws Exception {
        mockMvc.perform(post("/api/v1/contact").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Anna","email":"anna@example.com","message":""}
                                """))
                .andExpect(status().isBadRequest());

        verifyNoInteractions(mailService);
    }
}
