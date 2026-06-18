# Domain Model

## User

Fields:

* id
* email
* createdAt

## Food

Fields:

* id
* name
* caloriesPer100g
* proteinPer100g
* carbsPer100g (optional field)
* fatPer100g (optional field)

## Recipe

Fields:

* id
* name
* description

Relationships:

Recipe
-> many RecipeIngredients

## RecipeIngredient

Fields:

* recipeId
* foodId
* quantityInGrams

## Meal

Fields:

* id
* dateTime
* mealType

Meal Types:

* Breakfast
* Lunch
* Dinner
* Snack

## MealEntry

Fields:

* mealId
* foodId
* quantityInGrams

## Exercise

Fields:

* id
* name

## WorkoutTemplate

Fields:

* id
* name

## WorkoutTemplateExercise

Fields:

* workoutTemplateId
* exerciseId

## WorkoutSession

Fields:

* id
* startedAt
* finishedAt

## ExerciseSet

Fields:

* workoutSessionId
* exerciseId
* reps
* weight

## WeightEntry

Fields:

* id
* date
* weight
