-- LIF-146: named serving sizes on a food ("1 glass - 150 g", "1 slice - 30 g"), so logging one is a tap instead of arithmetic.
-- A short ordered list per food (the API caps it at 10), replaced as a whole on save. position keeps the order the owner chose;
-- the cascade removes them with the food row (foods are soft-deleted in practice, so this is only for a hard delete).
create table food_servings (
    food_id  bigint           not null references foods (id) on delete cascade,
    position integer          not null,
    name     varchar(40)      not null,
    grams    double precision not null check (grams > 0),
    primary key (food_id, position)
);
