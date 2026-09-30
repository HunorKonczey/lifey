import { z } from "zod";

// Messages are i18n keys (messages/*.json → "validation"), translated where
// the error is rendered — see useValidationMessage.

export const loginSchema = z.object({
  email: z.string().email("validation.emailInvalid"),
  password: z.string().min(8, "validation.passwordMin"),
});

export const registerSchema = z.object({
  firstName: z.string().min(1, "validation.firstNameRequired"),
  lastName: z.string().min(1, "validation.lastNameRequired"),
  email: z.string().email("validation.emailInvalid"),
  password: z.string().min(8, "validation.passwordMin"),
});

export const forgotPasswordSchema = z.object({
  email: z.string().email("validation.emailInvalid"),
});

export const resetPasswordSchema = z
  .object({
    code: z.string().regex(/^\d{6}$/, "validation.codeInvalid"),
    newPassword: z.string().min(8, "validation.passwordMin"),
    confirmPassword: z.string(),
  })
  .refine((d) => d.newPassword === d.confirmPassword, {
    message: "validation.passwordsMismatch",
    path: ["confirmPassword"],
  });

export const changePasswordSchema = z
  .object({
    currentPassword: z.string().min(1, "validation.required"),
    newPassword: z.string().min(8, "validation.passwordMin"),
    confirmPassword: z.string(),
  })
  .refine((d) => d.newPassword === d.confirmPassword, {
    message: "validation.passwordsMismatch",
    path: ["confirmPassword"],
  })
  .refine((d) => d.newPassword !== d.currentPassword, {
    message: "validation.passwordSameAsCurrent",
    path: ["newPassword"],
  });

export type LoginFormValues = z.infer<typeof loginSchema>;
export type RegisterFormValues = z.infer<typeof registerSchema>;
export type ForgotPasswordFormValues = z.infer<typeof forgotPasswordSchema>;
export type ResetPasswordFormValues = z.infer<typeof resetPasswordSchema>;
export type ChangePasswordFormValues = z.infer<typeof changePasswordSchema>;
