package com.lifey.nutrition.food;

import com.lifey.common.exception.DuplicateResourceException;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.food.dto.BarcodeLookupResponse;
import com.lifey.nutrition.food.dto.BarcodeSource;
import com.lifey.nutrition.food.dto.FoodResponse;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
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

    @Test
    void list_returnsOkWithJson() throws Exception {
        when(foodService.findAll())
                .thenReturn(List.of(new FoodResponse(1L, "Chicken", 165.0, 31.0, 0.0, 3.6, null, false)));

        mockMvc.perform(get("/api/v1/foods"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].name").value("Chicken"))
                .andExpect(jsonPath("$[0].caloriesPer100g").value(165.0));
    }

    @Test
    void create_returnsCreated() throws Exception {
        when(foodService.create(any()))
                .thenReturn(new FoodResponse(7L, "Rice", 130.0, 2.7, null, null, null, false));

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
}
