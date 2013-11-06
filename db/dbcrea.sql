drop database sopds;
commit;
create database sopds;
alter database sopds CHARSET utf8;
grant select,insert,update,delete on sopds.* to 'sopds'@'localhost' identified by 'sopds';
use sopds;

create table books (
book_id INT not null AUTO_INCREMENT,
filename VARCHAR(256),
fullpath VARCHAR(1024),
path VARCHAR(1024),
filesize INT not null DEFAULT 0,
format VARCHAR(8),
cat_id INT not null,
cat_tree VARCHAR(512),
autor_id INT not null DEFAULT 1,
registerdate TIMESTAMP not null DEFAULT CURRENT_TIMESTAMP,
favorite INT not null DEFAULT 0,
PRIMARY KEY(book_id),
KEY(filename),
KEY(cat_tree),
KEY(favorite));

create table catalogs (
cat_id INT not null AUTO_INCREMENT,
parent_id INT null,
cat_name VARCHAR(64),
full_path VARCHAR(1024),
path VARCHAR(1024),
PRIMARY KEY(cat_id),
KEY(cat_name,path));

create table tags (
tag_id INT not null AUTO_INCREMENT,
tag_type INT not null DEFAULT 0,
tag VARCHAR(64),
PRIMARY KEY(tag_id),
KEY(tag));

create table btags (
tag_id INT not null,
book_id INT not null,
PRIMARY KEY(book_id,tag_id));

create table autors (
autor_id INT not null AUTO_INCREMENT,
autor_name VARCHAR(120) not NULL,
PRIMARY KEY(autor_id),
KEY(autor_name));

insert into autors(autor_id,autor_name) values(1,"Неизвестный Автор");

commit;




