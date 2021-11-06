insert into departments (did, dname) values (0, 'Resignation Department');
insert into departments (did, dname) values (1, 'Research and Development');
insert into departments (did, dname) values (2, 'Finance & Accounting');
insert into departments (did, dname) values (3, 'Human Resources');
insert into departments (did, dname) values (4, 'Information Technology');
insert into departments (did, dname) values (5, 'Operations');
insert into departments (did, dname) values (6, 'Production & Manufacturing');
insert into departments (did, dname) values (7, 'Security');
insert into departments (did, dname) values (8, 'Sales & Marketing');
insert into departments (did, dname) values (9, 'Customer Service');
insert into departments (did, dname) values (10, 'Legal');

insert into employees (eid, ename, email, resigned_date, did, contact, home_contact, office_contact) values (1, 'Sherlock Hallibone', '1@meta.com', null, 1, 95508558,67997854,61022049);
insert into employees (eid, ename, email, resigned_date, did, contact, home_contact, office_contact) values (2, 'Lexine Rollingson', '2@meta.com', null, 2, 83599237,67399614,60364666);
insert into employees (eid, ename, email, resigned_date, did, contact, home_contact, office_contact) values (3, 'Crysta Hovard', '3@meta.com', null, 3, 86198664,65052505,60390906);
insert into employees (eid, ename, email, resigned_date, did, contact, home_contact, office_contact) values (4, 'Ketti Costellow', '4@meta.com', null, 4, 80360632,64009631,60821344);
insert into employees (eid, ename, email, resigned_date, did, contact, home_contact, office_contact) values (5, 'Odele Castano', '5@meta.com', null, 5, 86680403,62393189,60340627);
insert into employees (eid, ename, email, resigned_date, did, contact, home_contact, office_contact) values (6, 'Brit Maulden', '6@meta.com', null, 6, 88053051,65511144,60346275);
insert into employees (eid, ename, email, resigned_date, did, contact, home_contact, office_contact) values (7, 'Hagen Casin', '7@meta.com', null, 7, 86644368,61233827,60949120);
insert into employees (eid, ename, email, resigned_date, did, contact, home_contact, office_contact) values (8, 'Rafferty Eubank', '8@meta.com', null, 8, 80037756,64674318,60435886);
insert into employees (eid, ename, email, resigned_date, did, contact, home_contact, office_contact) values (9, 'Arlen Coultous', '9@meta.com', null, 9, 84396287,61405675,60629608);
insert into employees (eid, ename, email, resigned_date, did, contact, home_contact, office_contact) values (10, 'Elfrieda Clendening', '10@meta.com', null, 10, 83620502,62772297,60688726);


insert into juniors(eid) values ( 7 );
insert into juniors(eid) values ( 8 );
insert into juniors(eid) values ( 9 );
insert into juniors(eid) values ( 10 );

insert into Bookers(eid) values ( 1 );
insert into Bookers(eid) values ( 2 );
insert into Bookers(eid) values ( 3 );
insert into Bookers(eid) values ( 4 );
insert into Bookers(eid) values ( 5 );
insert into Bookers(eid) values ( 6 );

insert into Seniors(eid) values ( 4 );
insert into Seniors(eid) values ( 5 );
insert into Seniors(eid) values ( 6 );

insert into Managers(eid) values ( 1 );
insert into Managers(eid) values ( 2 );
insert into Managers(eid) values ( 3 );


insert into Meeting_Rooms (room, floor, rname, did) values (1, 1, 'A', 1);
insert into Meeting_Rooms (room, floor, rname, did) values (2, 1, 'B', 1);
insert into Meeting_Rooms (room, floor, rname, did) values (1, 2, 'C', 2);


insert into Updates (date, new_cap, room, floor,m_eid) values ('2020-07-01', 3, 1, 1, 1);
insert into Updates (date, new_cap, room, floor, m_eid) values ('2020-07-01', 3, 2, 1, 1);

insert into Updates (date, new_cap, room, floor, m_eid) values ('2020-07-01', 3, 1, 2, 2);


insert into Sessions (time, date, room, floor, b_eid) values (00, '2021/11/01', 1,1,1);
insert into Sessions (time, date, room, floor, b_eid) values (00, '2021/11/05', 1,1,1);
insert into Sessions (time, date, room, floor, b_eid) values (00, '2021/11/07', 2,1,1);

insert into Sessions (time, date, room, floor, b_eid) values (00, '2021/11/05', 1,2,2);
insert into Sessions (time, date, room, floor, b_eid) values (00, '2021/11/08', 1,2,2);
insert into Sessions (time, date, room, floor, b_eid) values (00, '2021/11/09', 1,2,2);

insert into Approves (time, date, room, floor, b_eid, m_eid) values (00, '2021/11/01', 1,1,1,1);
insert into Approves (time, date, room, floor, b_eid, m_eid) values (00, '2021/11/05', 1,1,1,1);
insert into Approves (time, date, room, floor, b_eid, m_eid) values (00, '2021/11/07', 2,1,1,1);

insert into Approves (time, date, room, floor, b_eid, m_eid) values (00, '2021/11/05', 1,2,2,2);
insert into Approves (time, date, room, floor, b_eid, m_eid) values (00, '2021/11/08', 1,2,2,2);



insert into Joins (time, date, room, floor, b_eid, e_eid) values (00, '2021/11/01', 1,1,1,1);
insert into Joins (time, date, room, floor, b_eid, e_eid) values (00, '2021/11/01', 1,1,1,2);
insert into Joins (time, date, room, floor, b_eid, e_eid) values (00, '2021/11/01', 1,1,1,3);

insert into Joins (time, date, room, floor, b_eid, e_eid) values (00, '2021/11/05', 1,1,1,1);
insert into Joins (time, date, room, floor, b_eid, e_eid) values (00, '2021/11/05', 1,1,1,5);
insert into Joins (time, date, room, floor, b_eid, e_eid) values (00, '2021/11/05', 1,1,1,6);

insert into Joins (time, date, room, floor, b_eid, e_eid) values (00, '2021/11/07', 2,1,1,1);
insert into Joins (time, date, room, floor, b_eid, e_eid) values (00, '2021/11/07', 2,1,1,7);
insert into Joins (time, date, room, floor, b_eid, e_eid) values (00, '2021/11/07', 2,1,1,8);

insert into Joins (time, date, room, floor, b_eid, e_eid) values (00, '2021/11/08', 1,2,2,2);
insert into Joins (time, date, room, floor, b_eid, e_eid) values (00, '2021/11/08', 1,2,2,9);

--- meeting room c
insert into Joins (time, date, room, floor, b_eid, e_eid) values (00, '2021/11/09', 1,2,2,2);
insert into Joins (time, date, room, floor, b_eid, e_eid) values (00, '2021/11/09', 1,2,2,9); -- unapproved




insert into Health_Declarations (date, temp, eid) values ('2021/11/06', 35, 1);


---- TESTING
select * from non_compliance('2021/11/01','2021/11/10' );

select * from contact_tracing(1, '2021/11/06');

SELECT * FROM view_booking_report('2021/10/01', 2);

select * from view_future_meeting('2021/10/01', 9);

select * from view_manager_report('2021/10/04', 2);

insert into Updates(date, new_cap,room,floor,m_eid) values  ('2021-11-06', 1, 1, 1, 1);


--- new data after functions and triggres are added
insert into Sessions (time, date, room, floor, b_eid) values (00, '2022/11/01', 1,1,1);
insert into Sessions (time, date, room, floor, b_eid) values (00, '2022/11/05', 1,1,1);
insert into Sessions (time, date, room, floor, b_eid) values (00, '2022/11/07', 2,1,1);

insert into Sessions (time, date, room, floor, b_eid) values (00, '2022/11/05', 1,2,2);
insert into Sessions (time, date, room, floor, b_eid) values (00, '2022/11/08', 1,2,2);
insert into Sessions (time, date, room, floor, b_eid) values (00, '2022/11/09', 1,2,2);

insert into Approves (time, date, room, floor, b_eid, m_eid) values (00, '2022/11/01', 1,1,1,1);
insert into Approves (time, date, room, floor, b_eid, m_eid) values (00, '2022/11/05', 1,1,1,1);
insert into Approves (time, date, room, floor, b_eid, m_eid) values (00, '2022/11/07', 2,1,1,1);

insert into Approves (time, date, room, floor, b_eid, m_eid) values (00, '2022/11/05', 1,2,2,2);
insert into Approves (time, date, room, floor, b_eid, m_eid) values (00, '2022/11/08', 1,2,2,2);

--delete from joins where date = '2021-11-01' and room = 2 and floor = 1 and b_eid = 1 and e_eid = 1;
-- delete from sessions where date = '2021-11-07' and room = 2 and floor = 1 and b_eid = 1;