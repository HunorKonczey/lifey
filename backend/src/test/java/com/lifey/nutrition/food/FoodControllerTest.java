package com.lifey.nutrition.food;

import com.lifey.common.exception.DuplicateResourceException;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.food.dto.BarcodeLookupResponse;
import com.lifey.nutrition.food.dto.BarcodeSource;
import com.lifey.nutrition.food.dto.FoodResponse;
import com.lifey.nutrition.food.dto.OffSearchItem;
import com.lifey.nutrition.food.dto.OffSearchResponse;
import com.lifey.nutrition.food.dto.OffSearchStatus;
import com.lifey.nutrition.food.service.BarcodeLookupService;
import com.lifey.nutrition.food.service.FoodNameSearchService;
import com.lifey.nutrition.food.service.FoodService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(FoodController.class)
class FoodControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    FoodService foodService;

    @MockitoBean
    BarcodeLookupService barcodeLookupService;

    @MockitoBean
    FoodNameSearchService foodNameSearchService;

    @Test
    void list_returnsOkWithJson() throws Exception {
        when(foodService.findAll())
                .thenReturn(List.of(new FoodResponse(1L, "Chicken", 165.0, 31.0, 0.0, 3.6, null, false, Instant.now(), null, null)));

        mockMvc.perform(get("/api/v1/foods"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].name").value("Chicken"))
                .andExpect(jsonPath("$[0].caloriesPer100g").value(165.0));
    }

    @Test
    void list_withNoParams_neverCallsPagedVariant() throws Exception {
        when(foodService.findAll())
                .thenReturn(List.of(new FoodResponse(1L, "Chicken", 165.0, 31.0, 0.0, 3.6, null, false, Instant.now(), null, null)));

        mockMvc.perform(get("/api/v1/foods")).andExpect(status().isOk());

        verify(foodService, never()).findPage(any(), any(), any());
    }

    @Test
    void findPage_firstPage_returnsPageEnvelope() throws Exception {
        Pageable pageable = PageRequest.of(0, 2, org.springframework.data.domain.Sort.by("name", "id"));
        Page<FoodResponse> page = new PageImpl<>(
                List.of(new FoodResponse(1L, "Chicken", 165.0, 31.0, 0.0, 3.6, null, false, Instant.now(), null, null)),
                pageable, 3);
        when(foodService.findPage(eq(pageable), isNull(), isNull())).thenReturn(page);

        mockMvc.perform(get("/api/v1/foods").param("page", "0").param("size", "2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].name").value("Chicken"))
                .andExpect(jsonPath("$.totalElements").value(3))
                .andExpect(jsonPath("$.totalPages").value(2))
                .andExpect(jsonPath("$.last").value(false));
    }

    @Test
    void findPage_lastPage_returnsLastTrue() throws Exception {
        Pageable pageable = PageRequest.of(1, 2, org.springframework.data.domain.Sort.by("name", "id"));
        Page<FoodResponse> page = new PageImpl<>(
                List.of(new FoodResponse(3L, "Rice", 130.0, 2.7, null, null, null, false, Instant.now(), null, null)),
                pageable, 3);
        when(foodService.findPage(eq(pageable), isNull(), isNull())).thenReturn(page);

        mockMvc.perform(get("/api/v1/foods").param("page", "1").param("size", "2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].name").value("Rice"))
                .andExpect(jsonPath("$.last").value(true));
    }

    @Test
    void findPage_withSearch_passesSearchThrough() throws Exception {
        Pageable pageable = PageRequest.of(0, 200, org.springframework.data.domain.Sort.by("name", "id"));
        Page<FoodResponse> page = new PageImpl<>(
                List.of(new FoodResponse(2L, "Rice cake", 380.0, 8.0, null, null, null, false, Instant.now(), null, null)),
                pageable, 1);
        when(foodService.findPage(eq(pageable), eq("rice"), isNull())).thenReturn(page);

        mockMvc.perform(get("/api/v1/foods").param("page", "0").param("search", "rice"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].name").value("Rice cake"));
    }

    @Test
    void findPage_withUpdatedSince_passesInstantThrough() throws Exception {
        Pageable pageable = PageRequest.of(0, 200, org.springframework.data.domain.Sort.by("name", "id"));
        Instant since = Instant.parse("2026-06-01T00:00:00Z");
        Page<FoodResponse> page = new PageImpl<>(
                List.of(new FoodResponse(4L, "Old Rice", 130.0, 2.7, null, null, null, false,
                        Instant.parse("2026-06-15T00:00:00Z"), Instant.parse("2026-06-15T00:00:00Z"), null)),
                pageable, 1);
        when(foodService.findPage(eq(pageable), isNull(), eq(since))).thenReturn(page);

        mockMvc.perform(get("/api/v1/foods").param("page", "0").param("updatedSince", since.toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].name").value("Old Rice"))
                .andExpect(jsonPath("$.content[0].deletedAt").exists());
    }

    @Test
    void create_returnsCreated() throws Exception {
        when(foodService.create(any()))
                .thenReturn(new FoodResponse(7L, "Rice", 130.0, 2.7, null, null, null, false, Instant.now(), null, null));

        mockMvc.perform(post("/api/v1/foods").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Rice\",\"caloriesPer100g\":130,\"proteinPer100g\":2.7,\"hidden\":false}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(7))
                .andExpect(jsonPath("$.name").value("Rice"));
    }

    @Test
    void create_invalidReturnsBadRequest() throws Exception {
        mockMvc.perform(post("/api/v1/foods").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"\",\"caloriesPer100g\":-1,\"proteinPer100g\":null}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.details").isArray());

        verify(foodService, never()).create(any());
    }

    @Test
    void create_duplicateNameReturns409() throws Exception {
        when(foodService.create(any()))
                .thenThrow(new DuplicateResourceException("A food named 'Rice' already exists"));

        mockMvc.perform(post("/api/v1/foods").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Rice\",\"caloriesPer100g\":130,\"proteinPer100g\":2.7,\"hidden\":false}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.status").value(409));
    }

    @Test
    void getById_notFoundReturns404() throws Exception {
        when(foodService.findById(99L)).thenThrow(new ResourceNotFoundException("Food not found: 99"));

        mockMvc.perform(get("/api/v1/foods/99"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404))
                .andExpect(jsonPath("$.message").value("Food not found: 99"));
    }

    @Test
    void delete_returnsNoContent() throws Exception {
        mockMvc.perform(delete("/api/v1/foods/1"))
                .andExpect(status().isNoContent());

        verify(foodService).delete(1L);
    }

    @Test
    void findByBarcode_returnsOkForLocalHit() throws Exception {
        when(barcodeLookupService.lookup("5901234123457"))
                .thenReturn(new BarcodeLookupResponse(1L, "Chicken", 165.0, 31.0, 0.0, 3.6,
                        "5901234123457", BarcodeSource.LOCAL));

        mockMvc.perform(get("/api/v1/foods/barcode/5901234123457"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(1))
                .andExpect(jsonPath("$.name").value("Chicken"))
                .andExpect(jsonPath("$.source").value("LOCAL"));
    }

    @Test
    void findByBarcode_returnsOkForOpenFoodFactsHit() throws Exception {
        when(barcodeLookupService.lookup("5901234123457"))
                .thenReturn(new BarcodeLookupResponse(null, "Cola", 42.0, 0.0, 10.6, 0.0,
                        "5901234123457", BarcodeSource.OPENFOODFACTS));

        mockMvc.perform(get("/api/v1/foods/barcode/5901234123457"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").doesNotExist())
                .andExpect(jsonPath("$.name").value("Cola"))
                .andExpect(jsonPath("$.source").value("OPENFOODFACTS"));
    }

    @Test
    void findByBarcode_notFoundReturns404() throws Exception {
        when(barcodeLookupService.lookup("0000000000000"))
                .thenThrow(new ResourceNotFoundException("No food found for barcode: 0000000000000"));

        mockMvc.perform(get("/api/v1/foods/barcode/0000000000000"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404));
    }

    // ---- GET /foods/off-search (docs/84)

    private static OffSearchResponse found(String language, boolean fellBack) {
        return new OffSearchResponse(OffSearchStatus.OK, language, fellBack,
                List.of(new OffSearchItem("4056489827702", "Csirkemell", "Pikok", 110.0, 14.0, 2.4, 4.9)));
    }

    @Test
    void offSearch_returnsTheResponseShape() throws Exception {
        when(foodNameSearchService.search("csirkemell", "hu")).thenReturn(found("hu", false));

        mockMvc.perform(get("/api/v1/foods/off-search").param("q", "csirkemell").param("lang", "hu"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("OK"))
                .andExpect(jsonPath("$.language").value("hu"))
                .andExpect(jsonPath("$.fellBackToEnglish").value(false))
                .andExpect(jsonPath("$.items[0].barcode").value("4056489827702"))
                .andExpect(jsonPath("$.items[0].name").value("Csirkemell"))
                .andExpect(jsonPath("$.items[0].brand").value("Pikok"))
                .andExpect(jsonPath("$.items[0].caloriesPer100g").value(110.0))
                .andExpect(jsonPath("$.items[0].proteinPer100g").value(14.0))
                .andExpect(jsonPath("$.items[0].carbsPer100g").value(2.4))
                .andExpect(jsonPath("$.items[0].fatPer100g").value(4.9));
    }

    @Test
    void offSearch_reportsAnEnglishFallback() throws Exception {
        when(foodNameSearchService.search("pumpkin", "hu")).thenReturn(found("en", true));

        mockMvc.perform(get("/api/v1/foods/off-search").param("q", "pumpkin").param("lang", "hu"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.language").value("en"))
                .andExpect(jsonPath("$.fellBackToEnglish").value(true));
    }

    @Test
    void offSearch_languageDefaultsToEnglish() throws Exception {
        when(foodNameSearchService.search("snickers", "en")).thenReturn(found("en", false));

        mockMvc.perform(get("/api/v1/foods/off-search").param("q", "snickers"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.language").value("en"));

        verify(foodNameSearchService).search("snickers", "en");
    }

    @Test
    void offSearch_handsTheTextOnAsTyped_sanitisingIsTheServicesJob() throws Exception {
        when(foodNameSearchService.search(eq("Túró Rudi"), eq("hu"))).thenReturn(found("hu", false));

        mockMvc.perform(get("/api/v1/foods/off-search").param("q", "Túró Rudi").param("lang", "hu"))
                .andExpect(status().isOk());

        verify(foodNameSearchService).search("Túró Rudi", "hu");
    }

    @Test
    void offSearch_anOpenFoodFactsProblemIsStillHttp200WithAStatus() throws Exception {
        when(foodNameSearchService.search("tej", "hu"))
                .thenReturn(new OffSearchResponse(OffSearchStatus.UNAVAILABLE, "hu", false, List.of()));
        when(foodNameSearchService.search("sajt", "hu"))
                .thenReturn(new OffSearchResponse(OffSearchStatus.RATE_LIMITED, "hu", false, List.of()));

        mockMvc.perform(get("/api/v1/foods/off-search").param("q", "tej").param("lang", "hu"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UNAVAILABLE"))
                .andExpect(jsonPath("$.items").isEmpty());
        mockMvc.perform(get("/api/v1/foods/off-search").param("q", "sajt").param("lang", "hu"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("RATE_LIMITED"));
    }

    @Test
    void offSearch_exactlyThreeLettersIsEnough() throws Exception {
        when(foodNameSearchService.search("tej", "en")).thenReturn(found("en", false));

        mockMvc.perform(get("/api/v1/foods/off-search").param("q", "tej")).andExpect(status().isOk());
    }

    @Test
    void offSearch_tooShortIs400_andOffIsNotAsked() throws Exception {
        mockMvc.perform(get("/api/v1/foods/off-search").param("q", "ab"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("at least 3")));

        verifyNoInteractions(foodNameSearchService);
    }

    @Test
    void offSearch_theMinimumCountsLettersAndDigitsAfterSanitising() throws Exception {
        for (String q : new String[]{"   ", ":::", "---", "\"a\"", "a b", "  ab  ", "ab:*", ""}) {
            mockMvc.perform(get("/api/v1/foods/off-search").param("q", q))
                    .andExpect(status().isBadRequest());
        }

        verifyNoInteractions(foodNameSearchService);
    }

    @Test
    void offSearch_aMissingQIs400() throws Exception {
        mockMvc.perform(get("/api/v1/foods/off-search"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Missing required parameter: q"));

        verifyNoInteractions(foodNameSearchService);
    }
}
