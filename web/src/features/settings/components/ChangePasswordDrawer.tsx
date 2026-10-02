"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useTranslations } from "next-intl";
import { useMutation } from "@tanstack/react-query";
import { Button, Drawer, PasswordField } from "@/components/ds";
import { authApi } from "@/features/auth/api";
import { changePasswordSchema, type ChangePasswordFormValues } from "@/features/auth/schemas";
import { useSessionStore } from "@/features/auth/store";
import { ApiError } from "@/lib/api/client";
import { useToast } from "@/lib/hooks/useToast";
import { useValidationMessage } from "@/lib/i18n/useValidationMessage";

/** "Jelszó módosítása" (W6.11): the three fields in a drawer; a wrong current password rings that field. */
export function ChangePasswordDrawer({ onClose }: { onClose: () => void }) {
  const t = useTranslations("settings");
  const common = useTranslations("common");
  const vm = useValidationMessage();
  const { show } = useToast();
  const { applyAccessToken } = useSessionStore();
  const {
    register, handleSubmit, setError,
    formState: { errors, isDirty },
  } = useForm<ChangePasswordFormValues>({
    resolver: zodResolver(changePasswordSchema),
    // Empty strings, not undefined: a registered input reads "" and would otherwise make the untouched form dirty.
    defaultValues: { currentPassword: "", newPassword: "", confirmPassword: "" },
  });

  const change = useMutation({
    mutationFn: (body: ChangePasswordFormValues) => authApi.changePassword({ currentPassword: body.currentPassword, newPassword: body.newPassword }),
    onSuccess: (res) => {
      applyAccessToken(res.accessToken, res.refreshToken);
      show(t("changePasswordSuccess"), "success");
      onClose();
    },
    onError: (err) => setError("currentPassword", { message: err instanceof ApiError ? err.message : t("changePasswordError") }),
  });

  return (
    <Drawer
      open
      onClose={onClose}
      width={480}
      title={t("changePassword")}
      isDirty={isDirty}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>{common("cancel")}</Button>
          <Button type="submit" form="change-password-form" disabled={change.isPending}>{t("changePassword")}</Button>
        </>
      }
    >
      <form id="change-password-form" onSubmit={handleSubmit((data) => change.mutate(data))} className="flex flex-col gap-5">
        <PasswordField label={t("currentPassword")} autoComplete="current-password" placeholder="••••••••" error={vm(errors.currentPassword?.message)} {...register("currentPassword")} />
        <PasswordField label={t("newPassword")} autoComplete="new-password" placeholder="••••••••" error={vm(errors.newPassword?.message)} {...register("newPassword")} />
        <PasswordField label={t("confirmNewPassword")} autoComplete="new-password" placeholder="••••••••" error={vm(errors.confirmPassword?.message)} {...register("confirmPassword")} />
      </form>
    </Drawer>
  );
}
