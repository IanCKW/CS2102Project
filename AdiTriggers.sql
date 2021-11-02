DROP TRIGGER IF EXISTS setEmployeeEmail ON Employees;
DROP TRIGGER IF EXISTS validJunior ON Juniors;
DROP TRIGGER IF EXISTS validBooker ON Bookers;
DROP TRIGGER IF EXISTS validSenior ON Seniors;
DROP TRIGGER IF EXISTS validManager ON Managers;

-- Check that new junior is not a booker
CREATE OR REPLACE FUNCTION juniorNotBooker()
RETURNS TRIGGER AS $$
DECLARE
    count NUMERIC;
BEGIN
    SELECT COUNT(*) INTO count
    FROM Bookers 
    WHERE NEW.eid = Bookers.eid; 

    IF count > 0 THEN
        RETURN NULL;
    ELSE 
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validJunior
BEFORE INSERT OR UPDATE ON Juniors
FOR EACH ROW EXECUTE FUNCTION juniorNotBooker();

-- Check that new booker is not a junior
CREATE OR REPLACE FUNCTION bookerNotJunior()
RETURNS TRIGGER AS $$
DECLARE
    count NUMERIC;
BEGIN
    SELECT COUNT(*) INTO count
    FROM Juniors
    WHERE NEW.eid = Juniors.eid;

    IF count > 0 THEN
        RETURN NULL;
    ELSE 
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validBooker
BEFORE INSERT OR UPDATE ON Bookers
FOR EACH ROW EXECUTE FUNCTION bookerNotJunior();

-- Check that new senior is not a manager
CREATE OR REPLACE FUNCTION seniorNotManager()
RETURNS TRIGGER AS $$
DECLARE
    count NUMERIC;
BEGIN
    SELECT COUNT(*) INTO count
    FROM Managers
    WHERE NEW.eid = Managers.eid;

    IF count > 0 THEN
        RETURN NULL;
    ELSE 
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validSenior
BEFORE INSERT OR UPDATE ON Seniors
FOR EACH ROW EXECUTE FUNCTION seniorNotManager();

-- Check that new manager is not a senior
CREATE OR REPLACE FUNCTION managerNotSenior()
RETURNS TRIGGER AS $$
DECLARE
    count NUMERIC;
BEGIN
    SELECT COUNT(*) INTO count
    FROM Seniors
    WHERE NEW.eid = Seniors.eid;
    
    IF count > 0 THEN
        RETURN NULL;
    ELSE 
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validManager
BEFORE INSERT OR UPDATE ON Managers
FOR EACH ROW EXECUTE FUNCTION managerNotSenior();

-- Autogenerate employee email addresses
CREATE OR REPLACE FUNCTION autogenerateEmployeeEmail()
RETURNS TRIGGER AS $$
BEGIN
    NEW.email := NEW.eid || '@meta.com';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER setEmployeeEmail
BEFORE INSERT OR UPDATE ON Employees
FOR EACH ROW EXECUTE FUNCTION autogenerateEmployeeEmail();