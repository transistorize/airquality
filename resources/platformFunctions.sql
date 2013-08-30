--
-- create_platform:
-- stored procedure to atomically create an entry in dim.platform with a unique id
-- inputs: platform_name - any length name
--         mac_address - MAC address of local machine, or any random passphrase
-- outputs: the key to the new entry in dim.platform
--
create or replace function create_platform(platform_name varchar, mac_address varchar) 
returns setof dim.platform as $$
declare
    ntime timestamp;
    namespace uuid;
    nuid uuid;
begin
    raise notice 'Name for new platform here is %', platform_name;
    select now() into ntime;
    select systemkey into namespace from kinisi.local;
    select uuid_generate_v5(namespace,
        mac_address
        || (extract( epoch from ntime )::bigint) :: varchar 
        || nextval('kinisi.local_salt_seq') :: varchar
        || platform_name) into nuid;
     
    insert into dim.platform (uid, name, created, current)
         values (nuid, platform_name, ntime, 1::bit(2));
    
    return query select * from dim.platform where uid = nuid;
end;
$$ language plpgsql;

