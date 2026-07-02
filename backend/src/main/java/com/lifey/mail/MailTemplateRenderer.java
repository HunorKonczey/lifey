package com.lifey.mail;

import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.util.Map;

/**
 * Renders the {@code src/main/resources/mail/*} templates. Deliberately just
 * {@code String.replace} on {@code {{placeholder}}} tokens — two emails don't
 * justify a template engine dependency (see docs/19-password-email-plan.md).
 */
@Component
public class MailTemplateRenderer {

    public String renderHtml(String templateName, MailLanguage language, Map<String, String> placeholders) {
        return render(templateName, language, "html", placeholders);
    }

    public String renderText(String templateName, MailLanguage language, Map<String, String> placeholders) {
        return render(templateName, language, "txt", placeholders);
    }

    private String render(String templateName, MailLanguage language, String extension, Map<String, String> placeholders) {
        String template = load(templateName, language, extension);
        for (Map.Entry<String, String> entry : placeholders.entrySet()) {
            template = template.replace("{{" + entry.getKey() + "}}", entry.getValue());
        }
        return template;
    }

    private String load(String templateName, MailLanguage language, String extension) {
        String path = "mail/" + templateName + "_" + language.name().toLowerCase() + "." + extension;
        try {
            return new ClassPathResource(path).getContentAsString(StandardCharsets.UTF_8);
        } catch (IOException e) {
            throw new UncheckedIOException("Missing mail template: " + path, e);
        }
    }
}
