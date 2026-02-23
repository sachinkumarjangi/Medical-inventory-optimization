create table date_dim(Dateofbill DATETIME,
 Bill_Day VARCHAR(10),
 Bill_Year INT,
 Month INT,
 Day INT,
 Date_ID INT PRIMARY KEY,
 Quarter VARCHAR(5)
 );
create table department( Dept_ID int PRIMARY KEY ,
 Specialisation varchar(20),
 Dept varchar(20) 
 );
create table product(Product_ID int PRIMARY KEY ,
 Formulation varchar(50),
 DrugName varchar(50) ,
 SubCat varchar(50),
 SubCat1 varchar(50) 
 );
 CREATE TABLE Fact_Sales (
    Typeofsales VARCHAR(10),
    Dateofbill DATE,
    Quantity DECIMAL,
    ReturnQuantity DECIMAL,
    Final_Cost DECIMAL,
    Final_Sales DECIMAL,
    RtnMRP DECIMAL,
    Dept_ID INT,
    Product_ID INT,
    Patient_ID VARCHAR(10),
    Transaction_ID INT PRIMARY KEY,
    Date_ID INT,
    FOREIGN KEY (Dept_ID) REFERENCES department(Dept_ID),
    FOREIGN KEY (Product_ID) REFERENCES product(Product_ID),
    FOREIGN KEY (Date_ID) REFERENCES date_dim(Date_ID)
);

 -- q1



WITH DrugRevenue AS (
    SELECT 
        p.DrugName,
        SUM(f.Final_Sales) AS TotalRevenue
    FROM Fact_Sales f
    JOIN product p 
        ON p.Product_ID = CAST(REGEXP_REPLACE(f.Product_ID, '[^0-9]', '') AS UNSIGNED)
    GROUP BY p.DrugName
),
CumulativeRevenue AS (
    SELECT 
        DrugName,
        TotalRevenue,
        SUM(TotalRevenue) OVER (ORDER BY TotalRevenue DESC) AS RunningRevenue,
        SUM(TotalRevenue) OVER () AS GrandTotal
    FROM DrugRevenue
)
SELECT 
    DrugName,
    TotalRevenue,
    ROUND((RunningRevenue / GrandTotal) * 100, 2) AS CumulativePercent
FROM CumulativeRevenue
ORDER BY TotalRevenue DESC
LIMIT 15;

-- Q2

SELECT 
    f.Product_ID,
    f.Quantity,
    f.ReturnQuantity,
    (f.Quantity - f.ReturnQuantity) AS NetSalesQty
FROM Fact_Sales f
LIMIT 10;


WITH TopDrugs AS (
    SELECT 
        p.DrugName,
        SUM(f.Final_Sales) AS TotalRevenue
    FROM Fact_Sales f
    JOIN product p 
        ON p.Product_ID = CAST(REGEXP_REPLACE(f.Product_ID, '[^0-9]', '') AS UNSIGNED)
    GROUP BY p.DrugName
    ORDER BY TotalRevenue DESC
    LIMIT 5
),
DailySales AS (
    SELECT 
        p.DrugName,
        f.Dateofbill,
        SUM(f.Quantity - f.ReturnQuantity) AS NetSalesQty
    FROM Fact_Sales f
    JOIN product p 
        ON p.Product_ID = CAST(REGEXP_REPLACE(f.Product_ID, '[^0-9]', '') AS UNSIGNED)
    WHERE p.DrugName IN (SELECT DrugName FROM TopDrugs)
    GROUP BY p.DrugName, f.Dateofbill
),
RollingAvg AS (
    SELECT
        DrugName,
        Dateofbill,
        AVG(NetSalesQty) OVER (
            PARTITION BY DrugName 
            ORDER BY Dateofbill
            ROWS BETWEEN 89 PRECEDING AND CURRENT ROW
        ) AS Rolling90DayAvg
    FROM DailySales
)
SELECT 
    DrugName,
    Dateofbill,
    ROUND(Rolling90DayAvg, 2) AS DynamicReorderPoint
FROM RollingAvg
ORDER BY DrugName, Dateofbill;

-- Q3



WITH CategoryWastage AS (
    SELECT 
        p.SubCat1,
        SUM(f.RtnMRP) AS TotalWastageValue,
        SUM(f.Final_Sales) AS TotalSalesValue
    FROM Fact_Sales f
    JOIN product p 
        ON p.Product_ID = CAST(REGEXP_REPLACE(f.Product_ID, '[^0-9]', '') AS UNSIGNED)
    GROUP BY p.SubCat1
),
RankedWastage AS (
    SELECT 
        SubCat1,
        TotalWastageValue,
        TotalSalesValue,
        ROUND((TotalWastageValue / SUM(TotalSalesValue) OVER ()) * 100, 2) AS PercentOfTotalSales
    FROM CategoryWastage
)
SELECT 
    SubCat1,
    ROUND(TotalWastageValue, 2) AS Total_Wastage_Value,
    ROUND(PercentOfTotalSales, 2) AS Percent_Of_Total_Sales
FROM RankedWastage
ORDER BY Total_Wastage_Value DESC
LIMIT 10;


-- Q4

SELECT 
    f.Dept_ID,
    d.Specialisation,
    f.Quantity,
    f.ReturnQuantity
FROM Fact_Sales f
JOIN department d 
    ON CAST(REGEXP_REPLACE(f.Dept_ID, '[^0-9]', '') AS UNSIGNED) = d.Dept_ID
LIMIT 10;

SELECT 
    d.Specialisation,
    SUM(f.Quantity) AS Total_Sold_Quantity,
    SUM(f.ReturnQuantity) AS Total_Returned_Quantity,
    ROUND((SUM(f.ReturnQuantity) / NULLIF(SUM(f.Quantity), 0)) * 100, 2) AS Return_Percentage
FROM Fact_Sales f
JOIN department d 
    ON CAST(REGEXP_REPLACE(f.Dept_ID, '[^0-9]', '') AS UNSIGNED) = d.Dept_ID
GROUP BY d.Specialisation
ORDER BY Return_Percentage DESC;

-- Q5



SELECT 
    p.Formulation,
    SUM(f.Final_Sales) AS Total_Sales,
    SUM(f.Final_Cost) AS Total_Cost,
    SUM(f.Final_Sales - f.Final_Cost) AS Gross_Profit,
    ROUND((SUM(f.Final_Sales - f.Final_Cost) / NULLIF(SUM(f.Final_Sales), 0)) * 100, 2) AS Gross_Profit_Margin_Percent
FROM Fact_Sales f
JOIN product p 
    ON CAST(REGEXP_REPLACE(f.Product_ID, '[^0-9]', '') AS UNSIGNED) = p.Product_ID
GROUP BY p.Formulation
ORDER BY Gross_Profit_Margin_Percent DESC;

-- Q6


SELECT 
    p.DrugName,
    p.Formulation,
    SUM(f.Final_Sales) AS Total_Sales,
    SUM(f.Final_Cost) AS Total_Cost,
    ROUND(((SUM(f.Final_Sales) - SUM(f.Final_Cost)) / NULLIF(SUM(f.Final_Sales), 0)) * 100, 2) AS Profit_Margin_Percent
FROM Fact_Sales f
JOIN product p 
    ON CAST(REGEXP_REPLACE(f.Product_ID, '[^0-9]', '') AS UNSIGNED) = p.Product_ID
GROUP BY p.DrugName, p.Formulation
HAVING ABS(SUM(f.Final_Sales) - SUM(f.Final_Cost)) <= 0.05 * SUM(f.Final_Sales)
ORDER BY Profit_Margin_Percent ASC;

-- Q7





WITH MonthlySales AS (
    SELECT 
        YEAR(STR_TO_DATE(Dateofbill, '%d-%m-%Y %H:%i')) AS Year,
        MONTH(STR_TO_DATE(Dateofbill, '%d-%m-%Y %H:%i')) AS Month,
        SUM(Quantity - ReturnQuantity) AS Net_Sales_Qty
    FROM Fact_Sales
QA),
Growth_Calc AS (
    SELECT 
        Year,
        Month,
        Net_Sales_Qty,
        ((Net_Sales_Qty - LAG(Net_Sales_Qty) OVER (ORDER BY Year, Month)) 
         / LAG(Net_Sales_Qty) OVER (ORDER BY Year, Month) * 100) AS MoM_Growth_Percent,
        ((Net_Sales_Qty - LAG(Net_Sales_Qty, 12) OVER (ORDER BY Year, Month)) 
         / LAG(Net_Sales_Qty, 12) OVER (ORDER BY Year, Month) * 100) AS YoY_Growth_Percent
    FROM MonthlySales
)
SELECT 
    Year,
    Month,
    ROUND(Net_Sales_Qty, 2) AS Net_Sales_Qty,
    ROUND(MoM_Growth_Percent, 2) AS MoM_Growth_Percent,
    COALESCE(ROUND(YoY_Growth_Percent, 2), 'N/A') AS YoY_Growth_Percent
FROM Growth_Calc
ORDER BY Year, Month;




-- Q8
SELECT  
    YEAR(STR_TO_DATE(f.Dateofbill, '%d-%m-%Y %H:%i')) AS Year,
    MONTHNAME(STR_TO_DATE(f.Dateofbill, '%d-%m-%Y %H:%i')) AS Month,
    SUM(f.Quantity - f.ReturnQuantity) AS Total_Demand
FROM Fact_Sales f
JOIN product p 
    ON p.Product_ID = CAST(REGEXP_REPLACE(f.Product_ID, '[^0-9]', '') AS UNSIGNED)
WHERE 
    p.SubCat1 = 'ANTI-INFECTIVES'
GROUP BY  
    YEAR(STR_TO_DATE(f.Dateofbill, '%d-%m-%Y %H:%i')),
    MONTHNAME(STR_TO_DATE(f.Dateofbill, '%d-%m-%Y %H:%i'))
ORDER BY  
    Total_Demand DESC
LIMIT 3;







-- Q9


SHOW COLUMNS FROM product;

SELECT  
    YEAR(STR_TO_DATE(f.Dateofbill, '%d-%m-%Y %H:%i')) AS Year,
    MONTHNAME(STR_TO_DATE(f.Dateofbill, '%d-%m-%Y %H:%i')) AS Month,
    p.SubCat1 AS Department,
    SUM((f.Quantity - f.ReturnQuantity) * f.Final_Sales) AS Total_Net_Sales,
    RANK() OVER (
        PARTITION BY  
            YEAR(STR_TO_DATE(f.Dateofbill, '%d-%m-%Y %H:%i')),
            MONTH(STR_TO_DATE(f.Dateofbill, '%d-%m-%Y %H:%i'))
        ORDER BY  
            SUM((f.Quantity - f.ReturnQuantity) * f.Final_Sales) DESC
    ) AS Rank_By_Sales
FROM Fact_Sales f
JOIN product p 
    ON p.Product_ID = CAST(REGEXP_REPLACE(f.Product_ID, '[^0-9]', '') AS UNSIGNED)
GROUP BY  
    YEAR(STR_TO_DATE(f.Dateofbill, '%d-%m-%Y %H:%i')),
    MONTH(STR_TO_DATE(f.Dateofbill, '%d-%m-%Y %H:%i')),
    MONTHNAME(STR_TO_DATE(f.Dateofbill, '%d-%m-%Y %H:%i')),
    p.SubCat1
ORDER BY  
    Year,
    MONTH(STR_TO_DATE(f.Dateofbill, '%d-%m-%Y %H:%i')),
    Rank_By_Sales;


-- Q10

SELECT  
    p.DrugName,
    MIN(STR_TO_DATE(f.Dateofbill, '%d-%m-%Y %H:%i')) AS First_Sale_Date
FROM Fact_Sales f
JOIN product p 
    ON p.Product_ID = CAST(REGEXP_REPLACE(f.Product_ID, '[^0-9]', '') AS UNSIGNED)
WHERE STR_TO_DATE(f.Dateofbill, '%d-%m-%Y %H:%i') IS NOT NULL
GROUP BY p.DrugName
ORDER BY First_Sale_Date;


-- Q11

SELECT  
    p.DrugName,
    CONCAT('Q', qtr) AS Quarter,
    ROUND(AVG(f.Quantity - f.ReturnQuantity), 2) AS Avg_Sales_Quantity
FROM (
    SELECT  
        f.*,
        QUARTER(STR_TO_DATE(f.Dateofbill, '%d-%m-%Y %H:%i')) AS qtr
    FROM Fact_Sales f
    WHERE STR_TO_DATE(f.Dateofbill, '%d-%m-%Y %H:%i') IS NOT NULL
) f
JOIN product p  
    ON p.Product_ID = CAST(REGEXP_REPLACE(f.Product_ID, '[^0-9]', '') AS UNSIGNED)
GROUP BY p.DrugName, qtr
ORDER BY p.DrugName, qtr;

-- Q12


WITH Drug_First_Sale AS (
    SELECT
        p.DrugName,
        MIN(STR_TO_DATE(f.Dateofbill, '%d-%m-%Y %H:%i')) AS First_Sale_Date
    FROM Fact_Sales f
    JOIN product p
        ON p.Product_ID = CAST(REGEXP_REPLACE(f.Product_ID, '[^0-9]', '') AS UNSIGNED)
    WHERE STR_TO_DATE(f.Dateofbill, '%d-%m-%Y %H:%i') IS NOT NULL
    GROUP BY p.DrugName
),
Five_Newest AS (
    SELECT
        DrugName,
        First_Sale_Date
    FROM Drug_First_Sale
    ORDER BY First_Sale_Date DESC
    LIMIT 5
)
SELECT
    p.DrugName,
    DATEDIFF(STR_TO_DATE(f.Dateofbill, '%d-%m-%Y %H:%i'), fn.First_Sale_Date) AS Days_Since_First_Sale,
    SUM(f.Quantity - f.ReturnQuantity) AS Total_Sales
FROM Fact_Sales f
JOIN product p
    ON p.Product_ID = CAST(REGEXP_REPLACE(f.Product_ID, '[^0-9]', '') AS UNSIGNED)
JOIN Five_Newest fn
    ON p.DrugName = fn.DrugName
WHERE STR_TO_DATE(f.Dateofbill, '%d-%m-%Y %H:%i') BETWEEN fn.First_Sale_Date AND DATE_ADD(fn.First_Sale_Date, INTERVAL 90 DAY)
GROUP BY p.DrugName, Days_Since_First_Sale
ORDER BY p.DrugName, Days_Since_First_Sale;


-- Q13



DESC Fact_Sales;
INSERT INTO Fact_Sales
(Typeofsales, Dateofbill, Quantity, ReturnQuantity, Final_Cost, Final_Sales, RtnMRP, Dept_ID, Product_ID, Patient_ID, Date_ID)
VALUES
('CASH', '01-01-2023 00:00', 5, 10, 50.00, 100.00, 20.00, 'D001', 'P001', 'PAT001', 20230101);
SELECT CONSTRAINT_NAME, CHECK_CLAUSE
FROM INFORMATION_SCHEMA.CHECK_CONSTRAINTS
WHERE CONSTRAINT_NAME = 'chk_qty_return';
INSERT INTO Fact_Sales
(Typeofsales, Dateofbill, Quantity, ReturnQuantity, Final_Cost, Final_Sales, RtnMRP, Dept_ID, Product_ID, Patient_ID, Date_ID)
VALUES
('CASH', '01-01-2023 00:00', 10, 5, 50.00, 100.00, 20.00, 'D001', 'P001', 'PAT001', 20230101);


-- Q14

CREATE TABLE FactInventory (
    Product_ID VARCHAR(50) PRIMARY KEY,
    Current_Stock DOUBLE DEFAULT 0,
    Last_Updated DATETIME DEFAULT NOW()
);

INSERT INTO FactInventory (Product_ID, Current_Stock)
VALUES ('P001', 100), ('P002', 200), ('P003', 150);

DELIMITER $$

CREATE TRIGGER trg_update_inventory_after_sale
AFTER INSERT ON Fact_Sales
FOR EACH ROW
BEGIN
    -- Subtract sold quantity (minus any returns) from inventory
    UPDATE FactInventory
    SET 
        Current_Stock = Current_Stock - (NEW.Quantity - NEW.ReturnQuantity),
        Last_Updated = NOW()
    WHERE Product_ID = NEW.Product_ID;
END $$

DELIMITER ;


INSERT INTO Fact_Sales (
    Typeofsales, Dateofbill, Quantity, ReturnQuantity, Final_Cost, Final_Sales,
    RtnMRP, Dept_ID, Product_ID, Patient_ID, Date_ID
)
VALUES ('CASH', '05-11-2025 10:00', 5, 1, 50.00, 100.00, 20.00, 'D001', 'P001', 'PAT002', 20251105);

SELECT * FROM FactInventory WHERE Product_ID = 'P001';



-- Q15

CREATE TABLE SupplierCost_Log (
    Log_ID INT AUTO_INCREMENT PRIMARY KEY,
    Product_ID VARCHAR(50),
    Old_Final_Cost DOUBLE,
    New_Final_Cost DOUBLE,
    Change_Date DATETIME DEFAULT NOW()
);

DELIMITER $$

CREATE TRIGGER trg_log_final_cost_change
BEFORE UPDATE ON Fact_Sales
FOR EACH ROW
BEGIN
    -- Check if the cost value is being changed
    IF OLD.Final_Cost <> NEW.Final_Cost THEN
        INSERT INTO SupplierCost_Log (Product_ID, Old_Final_Cost, New_Final_Cost, Change_Date)
        VALUES (OLD.Product_ID, OLD.Final_Cost, NEW.Final_Cost, NOW());
    END IF;
END $$

DELIMITER ;

UPDATE Fact_Sales
SET Final_Cost = 75.00
WHERE Product_ID = 'P001'
LIMIT 1;

SELECT * FROM SupplierCost_Log;

-- Q16


CREATE TABLE DimSupplier (
    Supplier_ID VARCHAR(50) PRIMARY KEY,
    Supplier_Name VARCHAR(100)
);
CREATE TABLE DimProduct (
    Product_ID VARCHAR(50) PRIMARY KEY,
    Product_Name VARCHAR(100),
    Supplier_ID VARCHAR(50),
    FOREIGN KEY (Supplier_ID) REFERENCES DimSupplier(Supplier_ID)
);


SELECT COUNT(*) FROM Fact_Sales;
SHOW TABLES;

SELECT * FROM DimProduct LIMIT 5;
SELECT * FROM DimSupplier LIMIT 5;

SELECT DISTINCT f.Product_ID
FROM Fact_Sales f
LEFT JOIN DimProduct p ON f.Product_ID = p.Product_ID
WHERE p.Product_ID IS NULL;

SELECT 
    s.Supplier_ID,
    s.Supplier_Name,
    SUM(f.Final_Sales - f.Final_Cost) AS Total_Net_Sales,
    RANK() OVER (ORDER BY SUM(f.Final_Sales - f.Final_Cost) DESC) AS Supplier_Rank
FROM Fact_Sales f
JOIN DimProduct p ON f.Product_ID = p.Product_ID
JOIN DimSupplier s ON p.Supplier_ID = s.Supplier_ID
GROUP BY s.Supplier_ID, s.Supplier_Name;



-- Q17

CREATE TABLE SupplierOrders (
    Order_ID INT AUTO_INCREMENT PRIMARY KEY,
    Supplier_ID VARCHAR(50),
    Product_ID VARCHAR(50),
    Order_Date DATE,
    Receipt_Date DATE,
    Quantity INT,
    FOREIGN KEY (Supplier_ID) REFERENCES DimSupplier(Supplier_ID),
    FOREIGN KEY (Product_ID) REFERENCES DimProduct(Product_ID)
);

INSERT INTO DimSupplier (Supplier_ID, Supplier_Name)
VALUES 
('S001', 'MediCorp Pharmaceuticals'),
('S002', 'HealthPlus Distributors');

INSERT INTO SupplierOrders (Supplier_ID, Product_ID, Order_Date, Receipt_Date, Quantity)
VALUES
('S001', 'P001', '2023-01-01', '2023-01-05', 100),
('S001', 'P002', '2023-01-10', '2023-01-15', 200),
('S002', 'P003', '2023-02-01', '2023-02-04', 150);
INSERT INTO DimProduct (Product_ID, Product_Name, Supplier_ID)
VALUES
('P001', 'Paracetamol 500mg', 'S001'),
('P002', 'Amoxicillin 250mg', 'S001'),
('P003', 'Cetirizine 10mg', 'S002');

SELECT * 
FROM SupplierOrders o
JOIN DimSupplier s ON o.Supplier_ID = s.Supplier_ID
JOIN DimProduct p ON o.Product_ID = p.Product_ID;

SELECT 
    s.Supplier_ID,
    s.Supplier_Name,
    ROUND(AVG(DATEDIFF(o.Receipt_Date, o.Order_Date)), 2) AS Avg_Lead_Time_Days
FROM SupplierOrders o
JOIN DimSupplier s ON o.Supplier_ID = s.Supplier_ID
WHERE o.Receipt_Date IS NOT NULL AND o.Order_Date IS NOT NULL
GROUP BY s.Supplier_ID, s.Supplier_Name
ORDER BY Avg_Lead_Time_Days;


-- Q18

SELECT 
    Patient_ID, 
    SUM(Final_Sales) AS Total_Revenue
FROM Fact_Sales
GROUP BY Patient_ID
ORDER BY Total_Revenue DESC
LIMIT 1;

SELECT 
    Product_ID,
    SUM(Quantity - ReturnQuantity) AS Net_Quantity_Sold
FROM Fact_Sales
WHERE Patient_ID = 'PAT001'
GROUP BY Product_ID
ORDER BY Net_Quantity_Sold DESC
LIMIT 5;

-- Q19
SELECT 
    Product_ID,
    ROUND(AVG(diff_days), 2) AS Avg_Days_Between_Sales
FROM (
    SELECT 
        Product_ID,
        STR_TO_DATE(Dateofbill, '%d-%m-%Y %H:%i') AS sale_date,
        DATEDIFF(
            STR_TO_DATE(Dateofbill, '%d-%m-%Y %H:%i'),
            LAG(STR_TO_DATE(Dateofbill, '%d-%m-%Y %H:%i')) 
                OVER (PARTITION BY Product_ID ORDER BY STR_TO_DATE(Dateofbill, '%d-%m-%Y %H:%i'))
        ) AS diff_days
    FROM Fact_Sales
) f
WHERE diff_days IS NOT NULL
GROUP BY Product_ID
ORDER BY Avg_Days_Between_Sales;

-- Q20

SELECT 
    d.Specialisation,
    SUM(f.Final_Sales) AS Total_Sales_Value,
    ROUND(SUM(f.Final_Sales) / (SELECT SUM(Final_Sales) FROM Fact_Sales) * 100, 2) AS Contribution_Percentage
FROM Fact_Sales f
JOIN DimPatient d 
    ON f.Patient_ID = d.Patient_ID
GROUP BY d.Specialisation
ORDER BY Total_Sales_Value DESC;












