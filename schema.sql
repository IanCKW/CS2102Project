DROP TABLE IF EXISTS Employees, Contacts, Juniors, Seniors, Bookers, Managers, Sessions, 
Departments, Meeting_Rooms, Updates, Approves, Joins, Health_Declarations CASCADE;

CREATE TABLE Departments (
    did INTEGER PRIMARY KEY,
    dname TEXT
);

CREATE TABLE Employees (
    eid INTEGER PRIMARY KEY,
    ename TEXT,
    email TEXT UNIQUE,
    resigned_date INTEGER,
    did INTEGER NOT NULL,
    FOREIGN KEY (did) REFERENCES Departments(did)
);

CREATE TABLE Contacts (
    eid INTEGER,
    number INTEGER,
    PRIMARY KEY (eid, number),
    FOREIGN KEY (eid) REFERENCES Employees(eid)
);

CREATE TABLE Juniors (
    eid INTEGER PRIMARY KEY,
    FOREIGN KEY (eid) REFERENCES Employees(eid)
);

CREATE TABLE Bookers (
    eid INTEGER PRIMARY KEY,
    FOREIGN KEY (eid) REFERENCES Employees(eid)
);

CREATE TABLE Seniors (
    eid INTEGER PRIMARY KEY,
    FOREIGN KEY (eid) REFERENCES Employees(eid),
    FOREIGN KEY (eid) REFERENCES Bookers(eid)
);

CREATE TABLE Managers (
    eid INTEGER PRIMARY KEY,
    FOREIGN KEY (eid) REFERENCES Employees(eid),
    FOREIGN KEY (eid) REFERENCES Bookers(eid)
);

CREATE TABLE Meeting_Rooms (
    room    INTEGER,
    floor   INTEGER,
    rname   TEXT,
    did     INTEGER NOT NULL,
    PRIMARY KEY (room, floor),
    FOREIGN KEY (did) REFERENCES Departments (did)
);

CREATE TABLE Updates(
    date    INTEGER primary key,
    new_cap INTEGER,
    room    INTEGER,
    floor   INTEGER,
    FOREIGN KEY (room, floor) REFERENCES Meeting_rooms (room, floor) 
);

CREATE TABLE Sessions (
    time    INTEGER,
    date    INTEGER,
    room    INTEGER,
    floor   INTEGER,
    eid     INTEGER not null,
    PRIMARY KEY (time, date, room, floor),
    FOREIGN KEY (room, floor) REFERENCES Meeting_Rooms (room, floor),
    FOREIGN KEY (eid) REFERENCES Bookers (eid)
);

CREATE TABLE Approves (
    time    INTEGER,
    date    INTEGER,
    room    INTEGER,
    floor   INTEGER,
    eid     INTEGER,
    PRIMARY KEY (time, date, room, floor),
    FOREIGN KEY (time, date, room, floor) REFERENCES Sessions (time, date, room, floor),
    FOREIGN KEY (eid) REFERENCES Managers (eid)
);

CREATE TABLE Joins (
    time    INTEGER,
    date    INTEGER,
    room    INTEGER,
    floor   INTEGER,
    eid     INTEGER,
    PRIMARY KEY (time, date, room, floor, eid),
    FOREIGN KEY (time, date, room, floor) REFERENCES Sessions(time, date, room, floor),
    FOREIGN KEY (eid) REFERENCES Employees (eid)
);

CREATE TABLE Health_Declarations (
    date    INTEGER,
    temp    INTEGER CHECK (temp > 34 and temp < 43),
    fever   INTEGER DEFAULT 0,
    eid     INTEGER,
    PRIMARY KEY (date, eid),
    FOREIGN KEY (eid) REFERENCES Employees(eid)
);