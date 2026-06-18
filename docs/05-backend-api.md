# Backend API Requirements

## Nutrition

GET /api/v1/foods

GET /api/v1/foods/{id}

POST /api/v1/foods

PUT /api/v1/foods/{id}

DELETE /api/v1/foods/{id}

## Recipes

GET /api/v1/recipes

GET /api/v1/recipes/{id}

POST /api/v1/recipes

PUT /api/v1/recipes/{id}

DELETE /api/v1/recipes/{id}

## Meals

GET /api/v1/meals

POST /api/v1/meals

PUT /api/v1/meals/{id}

DELETE /api/v1/meals/{id}

## Workouts

GET /api/v1/workout-templates

POST /api/v1/workout-templates

GET /api/v1/workout-sessions

POST /api/v1/workout-sessions

## Weight Tracking

GET /api/v1/weights

POST /api/v1/weights

DELETE /api/v1/weights/{id}

## Statistics

GET /api/v1/statistics/daily

GET /api/v1/statistics/weekly

GET /api/v1/statistics/monthly

## Technical Requirements

* OpenAPI documentation
* Validation
* Global exception handling
* Flyway migrations
* Unit tests
* Integration tests
* Docker support
