"use client";

import { useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { Button, ConfirmModal, Icon } from "@/components/ds";
import { Drawer } from "@/components/ds/overlay/Drawer";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";
import { ApiError } from "@/lib/api/client";
import { queryKeys } from "@/lib/api/queryKeys";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { useToast, TOAST_DURATION_MS } from "@/lib/hooks/useToast";
import { useUndoableDelete } from "@/lib/hooks/useUndoableDelete";
import { foodApi, mealApi } from "../api";
import { duplicateName, fieldsFromFood, foodRequest } from "../foodEdit";
import { computeFoodUsage } from "../usage";
import type { FoodRequest, FoodResponse } from "../types";
import { readOffSearchPreference, writeOffSearchPreference } from "../offSearch";
import { useOffSearchForLocale } from "../useOffSearch";
import { FoodEditor } from "./FoodEditor";
import { FoodsTable } from "./FoodsTable";
import { AddFoodFlow } from "./addFood/AddFoodFlow";

/**
 * The foods tab (W2.10): the table and, to its right from 1280 (above it below that), the editor panel for
 * the selected food or a new one. The table works on the whole food list — the same query the tab's count
 * and the add-food dialog use — so every column, "Utoljára" included, sorts across all foods.
 */
export function FoodsView() {
  const t = useTranslations("nutrition.foodsView");
  const te = useTranslations("nutrition.foodEditor");
  const common = useTranslations("common");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const undoableDelete = useUndoableDelete();
  const router = useRouter();

  const [editing, setEditing] = useState<{ food: FoodResponse | null; prefill?: Partial<FoodResponse>; key: string } | null>(null);
  const [nameError, setNameError] = useState<string | undefined>();
  const [barcodeLoading, setBarcodeLoading] = useState(false);
  const [deleting, setDeleting] = useState<FoodResponse | null>(null);
  const [logging, setLogging] = useState<FoodResponse | null>(null);
  const [now] = useState(() => new Date());
  const [editorDirty, setEditorDirty] = useState(false);
  const sidePanel = useMediaQuery("(min-width: 1280px)");

  const { data: foods, isLoading, isError, refetch } = useQuery({ queryKey: queryKeys.foods.all(), queryFn: foodApi.list });
  const { data: meals } = useQuery({ queryKey: queryKeys.meals.all(), queryFn: mealApi.list });
  const usage = computeFoodUsage(meals ?? []);

  const openNew = (prefill?: Partial<FoodResponse>) => {
    setNameError(undefined);
    setEditing({ food: null, prefill, key: `new:${prefill?.barcode ?? prefill?.name ?? ""}:${Date.now()}` });
  };
  const openFood = (food: FoodResponse) => {
    setNameError(undefined);
    setEditing({ food, key: `food:${food.id}` });
  };
  const closeEditor = () => {
    setEditing(null);
    setEditorDirty(false);
  };

  // "?new=<name>" arrives from the add-food dialog's empty result ("Create a new food “yoghurt”"):
  // open the editor with that name and clear the param so a reload doesn't reopen it.
  const newName = useSearchParams().get("new");
  useEffect(() => {
    if (newName == null) return;
    /* eslint-disable react-hooks/set-state-in-effect -- one-shot deep link, cleared from the URL right after */
    setNameError(undefined);
    setEditing({ food: null, prefill: { name: newName }, key: `new:${newName}` });
    /* eslint-enable react-hooks/set-state-in-effect */
    router.replace("/nutrition?tab=foods", { scroll: false });
  }, [newName, router]);

  const saveMutation = useMutation({
    mutationFn: ({ food, request }: { food: FoodResponse | null; request: FoodRequest }) =>
      food ? foodApi.update(food.id, request) : foodApi.create(request),
    onSuccess: (_saved, { food }) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.foods.all() });
      show(food ? te("updated") : te("created"), "success");
      closeEditor();
    },
    onError: (error) => {
      if (error instanceof ApiError && error.status === 409) setNameError(te("duplicateName"));
      else show(te("saveFailed"), "error");
    },
  });

  const duplicateMutation = useMutation({
    mutationFn: (food: FoodResponse) => {
      const original = fieldsFromFood(food);
      const request = foodRequest(
        { ...original, name: duplicateName(food.name, (foods ?? []).map((f) => f.name), t("copyWord")), barcode: "" },
        original,
        false,
      );
      return foodApi.create(request);
    },
    onSuccess: (copy) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.foods.all() });
      show(t("foodDuplicated"), "success");
      openFood(copy); // open the copy straight away — renaming it is the usual next step
    },
    onError: () => show(t("duplicateFailed"), "error"),
  });

  const setCachedFoods = (update: (list: FoodResponse[]) => FoodResponse[]) =>
    queryClient.setQueryData<FoodResponse[]>(queryKeys.foods.all(), (old) => update(old ?? []));

  // Delete = confirm → the food leaves the list and a toast offers Undo; the DELETE (a soft delete on the
  // backend — meals that used the food keep it) goes out when the window closes.
  const deleteFood = (food: FoodResponse) => {
    if (editing?.food?.id === food.id) closeEditor();
    undoableDelete({
      message: t("foodDeleted", { food: food.name }),
      path: `/foods/${food.id}`,
      remove: () => setCachedFoods((list) => list.filter((f) => f.id !== food.id)),
      restore: () =>
        setCachedFoods((list) =>
          list.some((f) => f.id === food.id) ? list : [...list, food].sort((a, b) => a.name.localeCompare(b.name)),
        ),
      errorMessage: t("deleteFailed"),
    });
  };

  const lookupBarcode = async (barcode: string) => {
    if (!barcode) return;
    setBarcodeLoading(true);
    try {
      const res = await foodApi.barcode(barcode);
      if (res.source === "LOCAL" && res.id != null) {
        openFood(await foodApi.get(res.id));
        show(t("foundInCatalog"), "success");
      } else {
        openNew({
          name: res.name,
          caloriesPer100g: res.caloriesPer100g,
          proteinPer100g: res.proteinPer100g,
          carbsPer100g: res.carbsPer100g ?? 0,
          fatPer100g: res.fatPer100g ?? 0,
          barcode: res.barcode,
        });
        show(t("loadedFromOff"), "success");
      }
    } catch {
      show(t("barcodeNotFound"), "warning");
    } finally {
      setBarcodeLoading(false);
    }
  };

  if (isLoading) return <Skeleton variant="table" />;
  if (isError) return <ErrorState onRetry={refetch} />;

  const list = foods ?? [];

  // Beside the table from 1280; below that a drawer (a bottom sheet on a phone) that asks before discarding edits.
  const editor = editing && (
    <FoodEditor
      key={editing.key}
      food={editing.food}
      prefill={editing.prefill}
      pending={saveMutation.isPending}
      nameError={nameError}
      onNameEdit={() => setNameError(undefined)}
      onSave={(request) => saveMutation.mutate({ food: editing.food, request })}
      onCancel={closeEditor}
      onLookupBarcode={lookupBarcode}
      lookupPending={barcodeLoading}
      bare={!sidePanel}
      onDirtyChange={setEditorDirty}
      useOff={useOffSearchForLocale}
      // Read when the editor opens (always after a click or a link, so on the client), shared with the add-food dialog.
      initialOffChecked={readOffSearchPreference()}
      onOffCheckedChange={writeOffSearchPreference}
    />
  );

  return (
    <div className="flex flex-col gap-6 xl:flex-row xl:items-start">
      {editing && sidePanel && (
        <div className="order-last w-[380px] shrink-0 sticky top-6">{editor}</div>
      )}

      <div className="min-w-0 flex-1">
        {list.length === 0 ? (
          <EmptyState
            icon="nutrition"
            title={t("noFoods")}
            body={t("addManually")}
            action={
              <Button onClick={() => openNew()}>
                <Icon name="add" size={20} />
                {t("newFood")}
              </Button>
            }
          />
        ) : (
          <FoodsTable
            foods={list}
            usage={usage}
            now={now}
            selectedId={editing?.food?.id ?? null}
            onOpen={openFood}
            onNew={() => openNew()}
            onDuplicate={(f) => duplicateMutation.mutate(f)}
            onLogToday={setLogging}
            onDelete={setDeleting}
          />
        )}
      </div>

      {editing && !sidePanel && (
        <Drawer
          open
          onClose={closeEditor}
          width={480}
          title={editing.food ? te("editFood") : te("newFood")}
          isDirty={editorDirty}
        >
          {editor}
        </Drawer>
      )}

      <ConfirmModal
        open={deleting != null}
        onClose={() => setDeleting(null)}
        onConfirm={() => {
          if (deleting) deleteFood(deleting);
          setDeleting(null);
        }}
        icon="delete"
        title={deleting ? t("deleteTitle", { food: deleting.name }) : ""}
        body={deleting ? t("deleteBody", { seconds: TOAST_DURATION_MS / 1000 }) : ""}
        cancelLabel={common("cancel")}
        confirmLabel={common("delete")}
      />

      {logging && (
        <AddFoodFlow
          date={now}
          initialQuery={logging.name}
          initialKey={`food:${logging.id}`}
          onClose={() => setLogging(null)}
        />
      )}
    </div>
  );
}
