-- UI language preference (SYSTEM follows the device locale).

alter table user_settings
    add column language varchar(20) not null default 'SYSTEM';
