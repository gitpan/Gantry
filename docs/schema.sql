create sequence "auth_users";
create table "auth_users" (
    "id"            int4 default nextval('auth_users_seq'::text) NOT NULL,
    "user_id"       int4 default currval('auth_users_seq') NOT NULL,
    "active"        bool,
    "user_name"     varchar,
    "passwd"        varchar,
    "crypt"         varchar,
    "first_name"    varchar,
    "last_name"     varchar,
    "email"         varchar,
	 CONSTRAINT auth_users_pk PRIMARY KEY (user_id)
);

create sequence "auth_groups_seq";
create table "auth_groups" (
    "id"            int4 default nextval('auth_groups_seq'::text) NOT NULL,
    "name"          varchar,
    "ident"			varchar,
	"description"   text
);

create sequence "auth_pages_seq";
create table "auth_pages" (
    "id"            int4 default nextval('auth_pages_seq'::text) NOT NULL,
    "user_perm"     int4,
    "group_perm"    int4,
    "world_perm"    int4,
    "owner_id"      int4,
    "group_id"      int4,
    "uri"           varchar,
    "title"         varchar
);

create sequence "auth_group_members_seq";
create table "auth_group_members" (
    "id"        int4 default nextval('auth_group_members_seq'::text) NOT NULL,
    "user_id"   int4,
    "group_id"  int4
);

