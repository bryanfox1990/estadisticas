-- DECLARACION DE VARIABLES
SET NOCOUNT ON;
DECLARE @objectid int;
DECLARE @indexid int;
DECLARE @partitioncount bigint;
DECLARE @schemaname nvarchar(130); 
DECLARE @objectname nvarchar(130); 
DECLARE @indexname nvarchar(130); 
DECLARE @partitionnum bigint;
DECLARE @partitions bigint;
DECLARE @frag float;
DECLARE @command nvarchar(4000); 
DECLARE @entrar BIT=1;


---REVISAR SI EXISTE LA TABLA TEMPORAL 
--SI EXISTA ELIMINARLA DE LA MEMORIA 
IF OBJECT_ID('tempdb..#tblIndices') IS NOT NULL
BEGIN
	 DROP TABLE #tblIndices
END

-- DECLARACION DE CONSULTA QUE ME DICE COMO ESTA 
-- EL NIVEL DE DEFRAGMENTACION

SELECT
    object_id AS objectid,
    index_id AS indexid,
    partition_number AS partitionnum,
    avg_fragmentation_in_percent AS frag
INTO #tblIndices
FROM sys.dm_db_index_physical_stats ( DB_ID(), NULL, NULL , NULL, 'LIMITED')
WHERE avg_fragmentation_in_percent > 5.0 AND index_id > 0 
--AND page_count > 1000;

-- DECLARACION DEL CURSOR 
DECLARE Cpartitions CURSOR FOR SELECT * FROM #tblIndices;

-- Apertura del cursor
OPEN Cpartitions;

-- ENTRAR CICLO
WHILE (@entrar=@entrar)
    BEGIN;
        FETCH NEXT
           FROM Cpartitions
           INTO @objectid, @indexid, @partitionnum, @frag;
        IF @@FETCH_STATUS < 0 BREAK;
        SELECT @objectname = QUOTENAME(o.name), @schemaname = QUOTENAME(s.name)
        FROM sys.objects AS o
        JOIN sys.schemas as s ON s.schema_id = o.schema_id
        WHERE o.object_id = @objectid;
        SELECT @indexname = QUOTENAME(name)
        FROM sys.indexes
        WHERE  object_id = @objectid AND index_id = @indexid;
        SELECT @partitioncount = count (*)
        FROM sys.partitions
        WHERE object_id = @objectid AND index_id = @indexid;


		--Porcentaje de fragmentación Instrucción a ejecutar
		--Entre 5% y 30%         ALTER INDEX REORGANIZE
		--Mayor al 30%           ALTER INDEX REBUILD



        IF @frag < 30.0
            SET @command = N'ALTER INDEX ' + @indexname + N' ON ' + @schemaname + N'.' + @objectname + N' REORGANIZE';
        IF @frag >= 30.0
            SET @command = N'ALTER INDEX ' + @indexname + N' ON ' + @schemaname + N'.' + @objectname + N' REBUILD';
        IF @partitioncount > 1
            SET @command = @command + N' PARTITION=' + CAST(@partitionnum AS nvarchar(10));
        EXEC (@command);
        PRINT N'Executed: ' + @command;
    END;

-- Cierre del cursor y liberacion
CLOSE Cpartitions;
DEALLOCATE Cpartitions;




-- Declaración de variables
    DECLARE @dbName    sysname
    DECLARE @sample int
    DECLARE @SQL nvarchar(4000)
    DECLARE @ID int
    DECLARE @Tabla sysname
    DECLARE @RowCnt int

    --Filtro por base de datos y porcentaje para recalculo de estadísticas
    SET @dbName = 'CMYVAL_stage'
    SET @sample = 100

    --Tabla temporal
    CREATE TABLE ##Tablas
    (
     TableID INT IDENTITY(1, 1) NOT NULL,
     TableName SYSNAME NOT NULL
    )

    --Alimentamos la tabla con la lista de tablas
    SET @SQL = ''
    SET @SQL = @SQL + 'INSERT INTO ##Tablas (TableName) '
    SET @SQL = @SQL + 'SELECT [name] FROM ' + @dbName + '.dbo.sysobjects WHERE xtype = ''U'' AND [name] <> ''dtproperties'''

	--SELECT [name] FROM cmyval.dbo.sysobjects WHERE xtype = 'U' AND [name] <> 'dtproperties'




    EXEC sp_executesql @statement = @SQL

    SELECT TOP 1 @ID = TableID, @Tabla = TableName
    FROM ##Tablas
    ORDER BY TableID

    SET @RowCnt = @@ROWCOUNT
   
    --Por cada tabla
    WHILE @RowCnt <> 0
    BEGIN

     SET @SQL = 'UPDATE STATISTICS ' + @dbname + '.dbo.[' + @Tabla + '] WITH SAMPLE ' + CONVERT(varchar(3), @sample) + ' PERCENT'

     EXEC sp_executesql @statement = @SQL

     SELECT TOP 1 @ID = TableID, @Tabla = TableName
     FROM ##Tablas
     WHERE TableID > @ID
     ORDER BY TableID

     SET @RowCnt = @@ROWCOUNT

    END

--Eliminamos la tabla
DROP TABLE ##Tablas






SELECT  OBJECT_NAME(IDX.OBJECT_ID) AS Table_Name, 
IDX.name AS Index_Name, 
IDXPS.index_type_desc AS Index_Type, 
IDXPS.avg_fragmentation_in_percent  Fragmentation_Percentage
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, NULL) IDXPS 
INNER JOIN sys.indexes IDX  ON IDX.object_id = IDXPS.object_id 
AND IDX.index_id = IDXPS.index_id 
ORDER BY Fragmentation_Percentage DESC


		ALTER INDEX [PK_STG_CALIFICATIVO]  ON STG_CALIFICATIVO REORGANIZE; --2
		DBCC SHOW_STATISTICS ('dbo.STG_REGISTROVENTA','PK__STG_REGI__459533BFF3B22649')
		DBCC SHOW_STATISTICS ('dbo.STG_UNIVERSO','PK_STG_UNIVERSO')
		SELECT COUNT(*) FROM STG_UNIVERSO