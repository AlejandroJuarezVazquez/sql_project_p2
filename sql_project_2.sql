SELECT * FROM  books;

SELECT * FROM  branch;

SELECT * FROM  employees;

SELECT * FROM  issued_status;

SELECT * FROM  members;

SELECT * FROM  return_status;

-- Project Task

-- Task 1. Create a New Book Record -- "978-1-60129-456-2', 'To Kill a Mockingbird', 'Classic', 6.00, 'yes', 'Harper Lee', 'J.B. Lippincott & Co.')"

INSERT INTO books(isbn, book_title, category, rental_price, status, author, publisher)
VALUES ('978-1-60129-456-2', 'To Kill a Mockingbird', 'Classic', 6.00, 'yes', 'Harper Lee', 'J.B. Lippincott & Co.');

-- Task 2: Update an Existing Member's Address

UPDATE members
SET member_address = '125 Main St'
WHERE member_id = 'C101'

-- Task 3: Delete a Record from the Issued Status Table 
-- Objective: Delete the record with issued_id = 'IS121' from the issued_status table.

SELECT * FROM issued_status

DELETE FROM issued_status
WHERE issued_id = 'IS121'

-- Task 4: Retrieve All Books Issued by a Specific Employee 
-- Objective: Select all books issued by the employee with emp_id = 'E101'.

SELECT * FROM  issued_status
WHERE issued_emp_id = 'E101';

-- Task 5: List Members Who Have Issued More Than One Book 
-- Objective: Use GROUP BY to find members who have issued more than one book.

SELECT
	issued_emp_id,
	COUNT(issued_id) as total_book_issued
FROM  issued_status
GROUP BY issued_emp_id
HAVING COUNT(issued_id) > 1

-- CTAS (Create Table As Select)

-- Task 6: Create Summary Tables: Used CTAS to generate new tables based on query results - each book and total book_issued_cnt**

CREATE TABLE book_counts
AS
SELECT
	b.isbn,
	b.book_title,
	COUNT(ist.issued_id) as no_issued
FROM books as b
JOIN
issued_status as ist
ON ist.issued_book_isbn = b.isbn
GROUP BY 1, 2;

SELECT * FROM book_counts


-- 4. Data Analysis & Findings: The following SQL queries were used to address specific questions

-- Task 7. Retrieve All Books in a Specific Category:

SELECT * FROM books
WHERE category = 'Classic'

-- Task 8: Find Total Rental Income by Category:

SELECT 
	b.category,
	SUM(b.rental_price) AS Total_Rental_Income,
	COUNT(*)
FROM books as b
JOIN
issued_status as ist
ON ist.issued_book_isbn = b.isbn
GROUP BY 1

-- List Members Who Registered in the Last 180 Days:

SELECT * FROM members
WHERE reg_date >= CURRENT_DATE - INTERVAL '180 days'

INSERT INTO members(member_id, member_name, member_address, reg_date)
VALUES
('C127', 'Sam', '145 Main St', '2024-08-01'),
('C131', 'John', '133 Main St', '2024-05-01');

-- List Employees with Their Branch Manager's Name and their branch details:

SELECT 
    e1.emp_id,
    e1.emp_name,
    e1.position,
    e1.salary,
    b.*,
    e2.emp_name as manager
FROM employees as e1
JOIN 
branch as b
ON e1.branch_id = b.branch_id    
JOIN
employees as e2
ON e2.emp_id = b.manager_id

-- Task 11. Create a Table of Books with Rental Price Above a Certain Threshold 7USD:


CREATE TABLE books_price_greater_than_7
AS	
SELECT * FROM books
WHERE rental_price > 7

SELECT * FROM books_price_greater_than_7

-- Task 12: Retrieve the List of Books Not Yet Returned

SELECT
	DISTINCT ist.issued_book_name
FROM issued_status as ist
LEFT JOIN 
return_status as rs
ON ist.issued_id = rs.issued_id
WHERE rs.return_id  IS NULL

-- END OF FIRST PART

-- Advanced SQL Operations

-- Task 13: Identify Members with Overdue Books
-- Write a query to identify members who have overdue books (assume a 30-day return period). 
-- Display the member's_id, member's name, book title, issue date, and days overdue.

SELECT
	ist.issued_member_id, -- Recupera el ID del miembro que solicitó el préstamo.
	m.member_name, -- Recupera el nombre del miembro, obtenido de la tabla de miembros.
	bk.book_title, -- Recupera el título del libro prestado.
	ist.issued_date, -- Recupera la fecha en que se emitió el préstamo.
	CURRENT_DATE - ist.issued_date as over_dues_days -- Calcula el número de días desde la fecha del préstamo hasta la fecha actual.
FROM issued_status as ist
JOIN 										-- Une la tabla members con la tabla issued_status usando issued_member_id y member_id.
members as m
	ON m.member_id = ist.issued_member_id
JOIN										-- Une la tabla books con la tabla issued_status usando la clave isbn.
books as bk
ON bk.isbn = ist.issued_book_isbn
LEFT JOIN									-- Realiza una unión izquierda con la tabla return_status basada en issued_id.
return_status as rs
ON rs.issued_id = ist.issued_id
WHERE										-- Filtra los registros para incluir libros no devueltos y libros con préstamos superiores a 30 días
	rs.return_date IS NULL
	AND
	(CURRENT_DATE - ist.issued_date) > 30
ORDER BY 1									-- Ordena los resultados por la primera columna del SELECT, que es ist.issued_member_id.


-- Task 14: Update Book Status on Return
-- Write a query to update the status of books in the books table to "Yes" 
-- when they are returned (based on entries in the return_status table).

CREATE OR REPLACE PROCEDURE add_return_records(
    p_return_id VARCHAR(10), 
    p_issued_id VARCHAR(10), 
    p_book_quality VARCHAR(10)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_isbn VARCHAR(50);
    v_book_name VARCHAR(80);
BEGIN
    -- Insertar en la tabla return_status usando los parámetros del procedimiento
    INSERT INTO return_status(return_id, issued_id, return_date, book_quality)
    VALUES
    (p_return_id, p_issued_id, CURRENT_DATE, p_book_quality);

    -- Obtener el ISBN y el nombre del libro de la tabla issued_status
    SELECT 
        issued_book_isbn,
        issued_book_name
    INTO
        v_isbn,
        v_book_name
    FROM issued_status
    WHERE issued_id = p_issued_id;

    -- Actualizar el estado del libro en la tabla books
    UPDATE books
    SET status = 'yes'
    WHERE isbn = v_isbn;

    -- Mostrar un mensaje de confirmación
    RAISE NOTICE 'Thank you for returning the book: %', v_book_name;
END;
$$;

-- Pruebas de la función

-- Verificar los datos del libro en la tabla books
SELECT * FROM books
WHERE isbn = '978-0-307-58837-1';

-- Verificar datos de préstamo en la tabla issued_status
SELECT * FROM issued_status
WHERE issued_book_isbn = '978-0-307-58837-1';

-- Verificar registros de devolución en la tabla return_status
SELECT * FROM return_status
WHERE issued_id = 'IS135';

-- Task 15: Branch Performance Report
-- Create a query that generates a performance report for each branch, showing the number of books issued, 
-- the number of books returned, and the total revenue generated from book rentals.

CREATE TABLE branch_reports
AS
SELECT
	b.branch_id	,									-- Recupera el ID de la sucursal
	b.manager_id,									-- Recupera el ID del gerente de la sucursal.
	COUNT(ist.issued_id) as number_book_issued,	-- Cuenta cuántos libros fueron emitidos 
	COUNT(rs.return_id) as number_book_return,		-- Cuenta cuántos libros fueron devueltos
	SUM(bk.rental_price) as total_revenue			-- Suma el precio de alquiler de los libros emitidos para calcular el ingreso total.
FROM issued_status as ist
JOIN
employees as e
ON e.emp_id = ist.issued_emp_id	-- Une issued_status con employees para asociar cada préstamo con el empleado que emitió el libro.
JOIN
branch as b
ON e.branch_id = b.branch_id		-- Une employees con branch para asociar cada préstamo con la sucursal correspondiente, 
									-- a través del empleado que realizó la emisión.
LEFT JOIN
return_status as rs					-- Une return_status con issued_status para incluir datos sobre las devoluciones.
ON rs.issued_id = ist.issued_id	-- Se usa un LEFT JOIN para incluir todos los préstamos, incluso aquellos sin devolución registrada.
JOIN					
books as bk							-- Une issued_status con books para asociar cada préstamo con los detalles del libro, 
ON ist.issued_book_isbn = bk.isbn	-- como su precio de alquiler (rental_price).
GROUP BY 1, 2			
									-- Agrupa los resultados por branch_id  y manager_id.
									-- Esto asegura que los cálculos se realicen para cada sucursal de manera independiente.
SELECT * FROM branch_reports

-- Task 16: CTAS: Create a Table of Active Members
-- Use the CREATE TABLE AS (CTAS) statement to create a new table active_members containing members who 
-- have issued at least one book in the last 2 months.

CREATE TABLE active_members
AS 
SELECT * FROM members
WHERE member_id IN (
					SELECT
						DISTINCT issued_member_id
					FROM issued_status
					WHERE
						issued_date >= CURRENT_DATE - INTERVAL '2 month'
					);
SELECT * FROM active_members

-- Task 17: Find Employees with the Most Book Issues Processed
-- Write a query to find the top 3 employees who have processed the most book issues. 
-- Display the employee name, number of books processed, and their branch.

SELECT 
	e.emp_name,										-- Selecciona el nombre del empleado.
	b.*,											-- Selecciona todas las columnas de branch, que contiene información de la sucursal.
	COUNT(ist.issued_id) as number_book_issued		-- Cuenta la cantidad de libros emitidos por el empleado, agrupando los datos.
FROM issued_status as ist
JOIN 												-- Une issued_status con employees para asociar cada registro 
employees as e										-- de emisión con el empleado que lo realizó.
ON e.emp_id = ist.issued_emp_id
JOIN												-- Une employees con branch para asociar a cada empleado con la sucursal en la que trabaja.
branch as b								
ON e.branch_id = b.branch_id
GROUP BY 1, 2										-- Agrupa los resultados y asegura que los conteos se calculen para cada 
													-- combinación única de empleado y sucursal.


-- Task 19: Stored Procedure 
-- Objective: Create a stored procedure to manage the status of books in a library system. 
-- Description: Write a stored procedure that updates the status of a book in the library based on its issuance. 
-- The procedure should function as follows: The stored procedure should take the book_id as an input parameter. 
-- The procedure should first check if the book is available (status = 'yes'). If the book is available, it should be issued, 
-- and the status in the books table should be updated to 'no'. If the book is not available (status = 'no'), 
-- the procedure should return an error message indicating that the book is currently not available.

CREATE OR REPLACE PROCEDURE issue_book(
										p_issued_id VARCHAR(10),
										p_issued_member_id VARCHAR(30),
										p_issued_book_isbn VARCHAR(30),
										p_issued_emp_id VARCHAR(10))
LANGUAGE plpgsql
AS $$

DECLARE 
	v_status VARCHAR(10);
BEGIN
	SELECT
		status
		INTO
		v_status
	FROM books
	WHERE isbn = p_issued_book_isbn;

	IF v_status = 'yes' THEN

		INSERT INTO issued_status(issued_id, issued_member_id, issued_date, issued_book_isbn, issued_emp_id)
		VALUES
		(p_issued_id, p_issued_member_id, CURRENT_DATE, p_issued_book_isbn, p_issued_emp_id);

		UPDATE books
			SET status = 'no'
		WHERE isbn = p_issued_book_isbn;

		RAISE NOTICE 'Book records added successfully for book isbn : %', p_issued_book_isbn;

		ELSE
			RAISE NOTICE 'Sorry to inform you the book you have requested is unavailable book_isbn: %', p_issued_book_isbn;
		END IF;
	END;
$$

-- Testing

SELECT * FROM books;
-- "978-0-553-29698-2" -- yes
-- "978-0-375-41398-8" -- no
SELECT * FROM issued_status;

CALL issue_book('IS155', 'C108', '978-0-553-29698-2', 'E104');
CALL issue_book('IS156', 'C108', '978-0-375-41398-8', 'E104');

SELECT * FROM books
WHERE isbn = '978-0-375-41398-8'

-- Task 20: Create Table As Select (CTAS) 
-- Objective: Create a CTAS (Create Table As Select) query to identify overdue books and calculate fines.
-- Description: Write a CTAS query to create a new table that lists each member and the books they have 
-- issued but not returned within 30 days. The table should include: The number of overdue books. 
-- The total fines, with each day's fine calculated at $0.50. The number of books issued by each member. 
-- The resulting table should show: Member ID Number of overdue books Total fines

CREATE TABLE overdue_books_report AS
SELECT
    m.member_id,			-- Identifica al miembro.
    COUNT(CASE WHEN CURRENT_DATE - ist.issued_date > 30 AND rs.return_date IS NULL THEN 1 END) AS number_overdue_books,	-- Cuenta cuántos libros están vencidos.
    SUM(CASE 																												-- Considera solo los libros cuya fecha de emisión supera los 30 días y no han sido devueltos
        WHEN CURRENT_DATE - ist.issued_date > 30 AND rs.return_date IS NULL -- Calcula las multas acumuladas.
        THEN (CURRENT_DATE - ist.issued_date - 30) * 0.50 					 -- Se resta el período de gracia de 30 días a la diferencia de fechas
        ELSE 0 																 -- Multiplica el número de días vencidos por $0.50.
    END) AS total_fines,
    COUNT(ist.issued_id) AS total_books_issued								-- Cuenta el total de libros emitidos por cada miembro.
FROM
    members AS m															-- Relaciona los miembros con los libros emitidos.
JOIN
    issued_status AS ist
    ON m.member_id = ist.issued_member_id
LEFT JOIN																	-- Relaciona los libros emitidos con sus devoluciones.
    return_status AS rs
    ON ist.issued_id = rs.issued_id
GROUP BY
    m.member_id;															-- Agrupa los resultados por cada miembro para calcular las métricas requeridas.

SELECT * FROM overdue_books_report 

-- END OF PROJECT


