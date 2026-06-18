-- Seed reference exercises. There is no exercise-management endpoint in the v1 API,
-- so these provide the master list that workout templates and sessions reference.

insert into exercises (name) values
    ('Bench Press'),
    ('Squat'),
    ('Deadlift'),
    ('Overhead Press'),
    ('Barbell Row'),
    ('Pull Up'),
    ('Bicep Curl'),
    ('Plank');
