package com.lifey.trainer;

import com.lifey.trainer.controller.TrainerInviteEmailController;
import com.lifey.trainer.exception.InviteNotFoundException;
import com.lifey.trainer.service.TrainerInviteService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * The links in the invite email are opened by mail security scanners and link previews before the person
 * clicks anything. A GET that recorded the answer accepted (or declined) the invite for them; the GET only
 * asks, and the button's POST answers.
 */
@WebMvcTest(TrainerInviteEmailController.class)
class TrainerInviteEmailControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    TrainerInviteService trainerInviteService;

    @Test
    void openingTheAcceptLink_changesNothing_andAsksForConfirmation() throws Exception {
        mockMvc.perform(get("/api/v1/trainer-invites/email/respond").param("token", "t0ken").param("accept", "true"))
                .andExpect(status().isOk())
                .andExpect(content().string(org.hamcrest.Matchers.containsString("Accept the invite?")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<form method=\"post\">")));

        verify(trainerInviteService, never()).respondViaEmailToken("t0ken", true);
    }

    @Test
    void openingTheDeclineLink_changesNothingEither() throws Exception {
        mockMvc.perform(get("/api/v1/trainer-invites/email/respond").param("token", "t0ken").param("accept", "false"))
                .andExpect(status().isOk())
                .andExpect(content().string(org.hamcrest.Matchers.containsString("Decline the invite?")));

        verify(trainerInviteService, never()).respondViaEmailToken("t0ken", false);
    }

    @Test
    void theConfirmationPageNeverEchoesTheToken() throws Exception {
        mockMvc.perform(get("/api/v1/trainer-invites/email/respond")
                        .param("token", "secret-token-value").param("accept", "true"))
                .andExpect(content().string(org.hamcrest.Matchers.not(org.hamcrest.Matchers.containsString("secret-token-value"))));
    }

    @Test
    void pressingTheButton_accepts() throws Exception {
        mockMvc.perform(post("/api/v1/trainer-invites/email/respond").param("token", "t0ken").param("accept", "true"))
                .andExpect(status().isOk())
                .andExpect(content().string(org.hamcrest.Matchers.containsString("Invite accepted")));

        verify(trainerInviteService).respondViaEmailToken("t0ken", true);
    }

    @Test
    void pressingTheButton_declines() throws Exception {
        mockMvc.perform(post("/api/v1/trainer-invites/email/respond").param("token", "t0ken").param("accept", "false"))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("Invite declined")));

        verify(trainerInviteService).respondViaEmailToken("t0ken", false);
    }

    @Test
    void anExpiredOrUsedLinkSaysSo() throws Exception {
        doThrow(new InviteNotFoundException("gone")).when(trainerInviteService).respondViaEmailToken("old", true);

        mockMvc.perform(post("/api/v1/trainer-invites/email/respond").param("token", "old").param("accept", "true"))
                .andExpect(status().isOk())
                .andExpect(content().string(org.hamcrest.Matchers.containsString("Link no longer valid")));
    }
}
