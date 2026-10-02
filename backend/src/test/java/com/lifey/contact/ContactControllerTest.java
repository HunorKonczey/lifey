package com.lifey.contact;

import com.lifey.mail.MailLanguage;
import com.lifey.mail.service.MailService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

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
                "Szabó Anna", "anna@example.com", "Kérdésem lenne az árakról.", MailLanguage.HU);
    }

    @Test
    void submit_unknownLocale_fallsBackToEnglish() throws Exception {
        mockMvc.perform(post("/api/v1/contact").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Anna","email":"anna@example.com","message":"Hi there."}
                                """))
                .andExpect(status().isNoContent());

        verify(mailService).sendContactMessage("Anna", "anna@example.com", "Hi there.", MailLanguage.EN);
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "{\"name\":\"Anna\",\"email\":\"\",\"message\":\"Hi there.\"}",
            "{\"name\":\"Anna\",\"email\":\"not-an-email\",\"message\":\"Hi there.\"}",
            "{\"name\":\"Anna\",\"email\":\"anna@example.com\",\"message\":\"\"}"
    })
    void submit_invalidBody_rejectedBeforeSending(String body) throws Exception {
        mockMvc.perform(post("/api/v1/contact").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isBadRequest());

        verifyNoInteractions(mailService);
    }
}
