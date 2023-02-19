/************************************************************************************
*Title:	Phone Number Clean Up														*
*************************************************************************************/
/************************************************************************************

Description: 
This script takes 'Mobile Number' of all candidates + 'Work Mobile' of all contacts 
and removes any whitespace or text from it, as well as changes the format of 
+44 / 0044 / +44(0) etc into '07xxx'. It also adds leading '0' to numbers without it
that start with '7'. This script also takes any text which was removed and records 
it as an action note.

Updated Date		Updated By				Comment
---------------------------------------------------------------------------------
17/12/2022			Peter Sallai			Script Created
*************************************************************************************/
GO
CREATE OR ALTER FUNCTION [dbo].[udf_ExtractNumbersFromString] (@Input varchar(max))
	RETURNS varchar(max)
	AS
	BEGIN
		-- Returns the index of a character that is not a number. If the specified pattern is not found, ZERO is returned
		DECLARE @AlphabetIndex int = PATINDEX('%[^0-9]%', @input)

		WHILE @AlphabetIndex > 0
		BEGIN
			-- In the input string (@input) at the position (@alphabetIndex) 
			-- Where we have a non-numeric chracter, replace that 1 character with an empty string ('')
			SET @Input = STUFF(@Input, @AlphabetIndex, 1, '')
			-- Find the next non-numeric character and repeat above step until all non-numeric characters are replaced with empty string
			SET @AlphabetIndex = PATINDEX('%[^0-9]%', @input)
		END

		RETURN @Input
	END
GO
/*************************************************************************************
**						DO NOT EDIT ANYTHING ABOVE THIS LINE						**
*************************************************************************************/

/*************************************************************************************
**							INFORMATION TO INPUT BELOW								**
*************************************************************************************/

DECLARE @DB varchar(MAX) = '' -- DB Name you are going to run the script against 

IF @DB <> DB_NAME() 
BEGIN
	RAISERROR ('Enter the client''s DB Name in the @DB variable at the top of the script AND in the DB dropdown to continue', 16, 1) WITH NOWAIT
	RETURN
END 

DECLARE @IsTestMode bit = 1

DECLARE @UpdateCandidates bit = 1
DECLARE @UpdateContacts bit = 1

DECLARE @RemoveText bit = 1
DECLARE @RemoveSpaces bit = 1
DECLARE @ChangeFormatForUKNumbers bit = 1 -- do you want to change +44 / 0044 / +44(0) etc into '07xxx'
DECLARE @AddLeadingZero bit = 1 -- add a leading '0' to numbers without it which start with '7'

/*************************************************************************************
**						DO NOT EDIT ANYTHING BELOW THIS LINE						**
*************************************************************************************/

BEGIN TRY
	DROP TABLE #CandidatesToUpdate
END TRY
BEGIN CATCH
END CATCH;

BEGIN TRY
	DROP TABLE #ContactsToUpdate
END TRY
BEGIN CATCH
END CATCH;

PRINT ''
PRINT '..get all the candidate records to be affected'
IF @UpdateCandidates = 1
BEGIN
	CREATE TABLE #CandidatesToUpdate (RowNumber int IDENTITY(1,1), CandidateID bigint, CandidateRefNo bigint, CandidateName varchar(max), OriginalMobileNumber varchar(max), TidyMobileNumber varchar(max), Note varchar(MAX))
	INSERT INTO #CandidatesToUpdate(CandidateID, CandidateRefNo, CandidateName, OriginalMobileNumber, TidyMobileNumber, Note)
	SELECT
		I.CandidateID
		,I.CandidateRefNo
		,I.CandidateName
		,I.OriginalMobileNumber
		,I.TidyMobileNumber
		,I.NoteFromMobile
	FROM
		(	SELECT
				I.CandidateID
				,I.CandidateRefNo
				,I.CandidateName
				,I.OriginalMobileNumber AS OriginalMobileNumber
				,(SELECT dbo.udf_ExtractNumbersFromString(I.NewMobileNumber)) AS TidyMobileNumber
				,I.NoteFromMobile 
			FROM
				(	SELECT
						CandidateID
						,CandidateRefNo
						,CandidateName
						,OriginalMobileNumber
						,REPLACE(NewMobileNumber, ' ', '') AS NewMobileNumber
						,NoteFromMobile
					FROM
						(	SELECT 
								P.ID AS CandidateID
								,C.DisplayID AS CandidateRefNo
								,P.FirstName + ' ' + P.Surname AS CandidateName
								,C.PhoneMobile AS OriginalMobileNumber
								,CASE
									WHEN C.PhoneMobile LIKE '7%' THEN CAST('0' + C.PhoneMobile AS varchar(50))
									WHEN C.PhoneMobile LIKE '+44 (0) 44%' THEN '0' + SUBSTRING(C.PhoneMobile, 11, 50)
									WHEN C.PhoneMobile LIKE '+44 (0) %' THEN '0' + SUBSTRING(C.PhoneMobile, 9, 50)
									WHEN C.PhoneMobile LIKE '+44( 0 )%' THEN '0' + SUBSTRING(C.PhoneMobile, 9, 50)
									WHEN C.PhoneMobile LIKE '+44 (0)%' THEN '0' + SUBSTRING(C.PhoneMobile, 8, 50)
									WHEN C.PhoneMobile LIKE '+44(0)%' THEN '0' + SUBSTRING(C.PhoneMobile, 7, 50)
									WHEN C.PhoneMobile LIKE '+44 0 %' THEN '0' + SUBSTRING(C.PhoneMobile, 7, 50)
									WHEN C.PhoneMobile LIKE '+44 0%' THEN '0' + SUBSTRING(C.PhoneMobile, 6, 50)
									WHEN C.PhoneMobile LIKE '+44 %' THEN '0' + SUBSTRING(C.PhoneMobile, 5, 50)
									WHEN C.PhoneMobile LIKE '+44) 0%' THEN '0' + SUBSTRING(C.PhoneMobile, 7, 50)
									WHEN C.PhoneMobile LIKE '+44) %' THEN '0' + SUBSTRING(C.PhoneMobile, 6, 50)
									WHEN C.PhoneMobile LIKE '+440%' THEN '0' + SUBSTRING(C.PhoneMobile, 5, 50)
									WHEN C.PhoneMobile LIKE '+44%' THEN '0' + SUBSTRING(C.PhoneMobile, 4, 50)
									WHEN C.PhoneMobile LIKE '0044 (0) %' THEN '0' + SUBSTRING(C.PhoneMobile, 10, 50)
									WHEN C.PhoneMobile LIKE '00440%' THEN '0' + SUBSTRING(C.PhoneMobile, 6, 50)
									WHEN C.PhoneMobile LIKE '0044 %' THEN '0' + SUBSTRING(C.PhoneMobile, 6, 50)
									WHEN C.PhoneMobile LIKE '0044%' THEN '0' + SUBSTRING(C.PhoneMobile, 5, 50)
								END AS NewMobileNumber
								,dbo.udf_trim(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(C.PhoneMobile, '0', ''), '1', ''), '2', ''), '3', ''), '4', ''), '5', ''), '6', ''), '7', ''), '8', ''), '9', '')) AS NoteFromMobile
							FROM
								Person P
								INNER JOIN Candidate C ON C.ID = P.ID
							WHERE
								C.PhoneMobile LIKE '7%'
								OR C.PhoneMobile LIKE '+44 (0) 44%'
								OR C.PhoneMobile LIKE '+44 (0) %'
								OR C.PhoneMobile LIKE '+44( 0 )%'
								OR C.PhoneMobile LIKE '+44 (0)%'
								OR C.PhoneMobile LIKE '+44(0)%'
								OR C.PhoneMobile LIKE '+44 0 %'
								OR C.PhoneMobile LIKE '+44 0%'
								OR C.PhoneMobile LIKE '+44 %'
								OR C.PhoneMobile LIKE '+44) 0%'
								OR C.PhoneMobile LIKE '+44) %'
								OR C.PhoneMobile LIKE '+440%'
								OR C.PhoneMobile LIKE '+44%'
								OR C.PhoneMobile LIKE '0044 (0) %'
								OR C.PhoneMobile LIKE '00440%'
								OR C.PhoneMobile LIKE '0044 %'
								OR C.PhoneMobile LIKE '0044%'
								OR 
								(	C.PhoneMobile LIKE '%[^0-9]%'
									AND C.PhoneMobile LIKE '%[a-zA-Z]%'
								)
						) I
				) I
		) I
	WHERE
		I.OriginalMobileNumber <> I.TidyMobileNumber
END

PRINT ''
PRINT '..get all the contact records to be affected'
IF @UpdateContacts = 1
BEGIN
	CREATE TABLE #ContactsToUpdate (RowNumber int IDENTITY(1,1), ContactID bigint, ContactRefNo bigint, ContactName varchar(max), OriginalMobileNumber varchar(max), TidyMobileNumber varchar(MAX), Note varchar(MAX))
	INSERT INTO #ContactsToUpdate(ContactID, ContactRefNo, ContactName, OriginalMobileNumber, TidyMobileNumber, Note)
	SELECT
		I.ContactID
		,I.ContactRefNo
		,I.ContactName
		,I.OriginalMobileNumber
		,I.TidyMobileNumber
		,I.NoteFromMobile
	FROM
		(	SELECT
				I.ContactID
				,I.ContactRefNo
				,I.ContactName
				,I.OriginalMobileNumber AS OriginalMobileNumber
				,(SELECT dbo.udf_ExtractNumbersFromString(I.NewMobileNumber)) AS TidyMobileNumber
				,I.NoteFromMobile 
			FROM
				(	SELECT
						ContactID
						,ContactRefNo
						,ContactName
						,OriginalMobileNumber
						,REPLACE(NewMobileNumber, ' ', '') AS NewMobileNumber
						,NoteFromMobile
					FROM
						(	SELECT 
								P.ID AS ContactID
								,P.DisplayID AS ContactRefNo
								,P.FirstName + ' ' + P.Surname AS ContactName
								,P.WorkMob AS OriginalMobileNumber
								,CASE
									WHEN P.WorkMob LIKE '7%' THEN CAST('0' + P.WorkMob AS varchar(50))
									WHEN P.WorkMob LIKE '+44 (0) 44%' THEN '0' + SUBSTRING(P.WorkMob, 11, 50)
									WHEN P.WorkMob LIKE '+44 (0) %' THEN '0' + SUBSTRING(P.WorkMob, 9, 50)
									WHEN P.WorkMob LIKE '+44( 0 )%' THEN '0' + SUBSTRING(P.WorkMob, 9, 50)
									WHEN P.WorkMob LIKE '+44 (0)%' THEN '0' + SUBSTRING(P.WorkMob, 8, 50)
									WHEN P.WorkMob LIKE '+44(0)%' THEN '0' + SUBSTRING(P.WorkMob, 7, 50)
									WHEN P.WorkMob LIKE '+44 0 %' THEN '0' + SUBSTRING(P.WorkMob, 7, 50)
									WHEN P.WorkMob LIKE '+44 0%' THEN '0' + SUBSTRING(P.WorkMob, 6, 50)
									WHEN P.WorkMob LIKE '+44 %' THEN '0' + SUBSTRING(P.WorkMob, 5, 50)
									WHEN P.WorkMob LIKE '+44) 0%' THEN '0' + SUBSTRING(P.WorkMob, 7, 50)
									WHEN P.WorkMob LIKE '+44) %' THEN '0' + SUBSTRING(P.WorkMob, 6, 50)
									WHEN P.WorkMob LIKE '+440%' THEN '0' + SUBSTRING(P.WorkMob, 5, 50)
									WHEN P.WorkMob LIKE '+44%' THEN '0' + SUBSTRING(P.WorkMob, 4, 50)
									WHEN P.WorkMob LIKE '0044 (0) %' THEN '0' + SUBSTRING(P.WorkMob, 10, 50)
									WHEN P.WorkMob LIKE '00440%' THEN '0' + SUBSTRING(P.WorkMob, 6, 50)
									WHEN P.WorkMob LIKE '0044 %' THEN '0' + SUBSTRING(P.WorkMob, 6, 50)
									WHEN P.WorkMob LIKE '0044%' THEN '0' + SUBSTRING(P.WorkMob, 5, 50)
								END AS NewMobileNumber
								,dbo.udf_trim(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(P.WorkMob, '0', ''), '1', ''), '2', ''), '3', ''), '4', ''), '5', ''), '6', ''), '7', ''), '8', ''), '9', '')) AS NoteFromMobile
							FROM
								Person P
							WHERE
								P.WorkMob LIKE '7%'
								OR P.WorkMob LIKE '+44 (0) 44%'
								OR P.WorkMob LIKE '+44 (0) %'
								OR P.WorkMob LIKE '+44( 0 )%'
								OR P.WorkMob LIKE '+44 (0)%'
								OR P.WorkMob LIKE '+44(0)%'
								OR P.WorkMob LIKE '+44 0 %'
								OR P.WorkMob LIKE '+44 0%'
								OR P.WorkMob LIKE '+44 %'
								OR P.WorkMob LIKE '+44) 0%'
								OR P.WorkMob LIKE '+44) %'
								OR P.WorkMob LIKE '+440%'
								OR P.WorkMob LIKE '+44%'
								OR P.WorkMob LIKE '0044 (0) %'
								OR P.WorkMob LIKE '00440%'
								OR P.WorkMob LIKE '0044 %'
								OR P.WorkMob LIKE '0044%'
								OR 
								(	P.WorkMob LIKE '%[^0-9]%'
									AND P.WorkMob LIKE '%[a-zA-Z]%'
								)
						) I
				) I
		) I
	WHERE
		I.OriginalMobileNumber <> I.TidyMobileNumber
END

IF @AddLeadingZero = 0
BEGIN
	
	PRINT ''
	PRINT '..remove candidate records which would have leading zero added'
	DELETE CU
	FROM
		#CandidatesToUpdate CU
	WHERE
		CU.OriginalMobileNumber LIKE '7%'
	
	PRINT ''
	PRINT '..remove contact records which would have leading zero added'
	DELETE CU
	FROM
		#ContactsToUpdate CU
	WHERE
		CU.OriginalMobileNumber LIKE '7%'
END

IF @ChangeFormatForUKNumbers = 0
BEGIN
	
	PRINT ''
	PRINT '..remove candidate records which would have format changed for UK numbers'
	DELETE CU
	FROM
		#CandidatesToUpdate CU
	WHERE
		CU.OriginalMobileNumber LIKE '+44 (0) 44%'
		OR CU.OriginalMobileNumber LIKE '+44 (0) %'
		OR CU.OriginalMobileNumber LIKE '+44( 0 )%'
		OR CU.OriginalMobileNumber LIKE '+44 (0)%'
		OR CU.OriginalMobileNumber LIKE '+44(0)%'
		OR CU.OriginalMobileNumber LIKE '+44 0 %'
		OR CU.OriginalMobileNumber LIKE '+44 0%'
		OR CU.OriginalMobileNumber LIKE '+44 %'
		OR CU.OriginalMobileNumber LIKE '+44) 0%'
		OR CU.OriginalMobileNumber LIKE '+44) %'
		OR CU.OriginalMobileNumber LIKE '+440%'
		OR CU.OriginalMobileNumber LIKE '+44%'
		OR CU.OriginalMobileNumber LIKE '0044 (0) %'
		OR CU.OriginalMobileNumber LIKE '00440%'
		OR CU.OriginalMobileNumber LIKE '0044 %'
		OR CU.OriginalMobileNumber LIKE '0044%'
	
	PRINT ''
	PRINT '..remove contact records which would have format changed for UK numbers'
	DELETE CU
	FROM
		#ContactsToUpdate CU
	WHERE
		CU.OriginalMobileNumber LIKE '+44 (0) 44%'
		OR CU.OriginalMobileNumber LIKE '+44 (0) %'
		OR CU.OriginalMobileNumber LIKE '+44( 0 )%'
		OR CU.OriginalMobileNumber LIKE '+44 (0)%'
		OR CU.OriginalMobileNumber LIKE '+44(0)%'
		OR CU.OriginalMobileNumber LIKE '+44 0 %'
		OR CU.OriginalMobileNumber LIKE '+44 0%'
		OR CU.OriginalMobileNumber LIKE '+44 %'
		OR CU.OriginalMobileNumber LIKE '+44) 0%'
		OR CU.OriginalMobileNumber LIKE '+44) %'
		OR CU.OriginalMobileNumber LIKE '+440%'
		OR CU.OriginalMobileNumber LIKE '+44%'
		OR CU.OriginalMobileNumber LIKE '0044 (0) %'
		OR CU.OriginalMobileNumber LIKE '00440%'
		OR CU.OriginalMobileNumber LIKE '0044 %'
		OR CU.OriginalMobileNumber LIKE '0044%'
END

IF @RemoveSpaces = 0
BEGIN
	
	PRINT ''
	PRINT '..remove candidate records which would have spaces removed'
	DELETE CU
	FROM
		#CandidatesToUpdate CU
	WHERE
		CU.OriginalMobileNumber LIKE '% %'
	
	PRINT ''
	PRINT '..remove contact records which would have spaces removed'
	DELETE CU
	FROM
		#ContactsToUpdate CU
	WHERE
		CU.OriginalMobileNumber LIKE '% %'
END

IF @RemoveText = 0
BEGIN
	
	PRINT ''
	PRINT '..remove candidate records which would have all text removed'
	DELETE CU
	FROM
		#CandidatesToUpdate CU
	WHERE
		CU.OriginalMobileNumber LIKE '%[^0-9]%'
		AND CU.OriginalMobileNumber LIKE '%[a-zA-Z]%'
	
	PRINT ''
	PRINT '..remove contact records which would have all text removed'
	DELETE CU
	FROM
		#ContactsToUpdate CU
	WHERE
		CU.OriginalMobileNumber LIKE '%[^0-9]%'
		AND CU.OriginalMobileNumber LIKE '%[a-zA-Z]%'
END

SELECT 'Candidates to be updated'
SELECT
	*
FROM
	#CandidatesToUpdate

SELECT 'Contacts to be updated'
SELECT
	*
FROM
	#ContactsToUpdate

DECLARE @BeginningTime datetime 
DECLARE @EndTime datetime
DECLARE @Duration int

DECLARE @Min int = 1
DECLARE @MaxForCandidate int = (SELECT MAX(CU.RowNumber) FROM #CandidatesToUpdate CU)
DECLARE @MaxForContact int = (SELECT MAX(CU.RowNumber) FROM #ContactsToUpdate CU)
DECLARE @Max int = CASE 
					   WHEN @MaxForCandidate >= @MaxForContact THEN @MaxForCandidate
					   ELSE @MaxForContact
				   END
DECLARE @WebSiteID int = (SELECT dbo.udf_GetPrimaryWebSiteID())
DECLARE @DataNodeID int = (SELECT D.DataNodeID FROM dbo.udf_GetDataNodeIDs(1) D)
DECLARE @CandidateActionID uniqueidentifier = (SELECT A.ID FROM uvw_Action_NamesAndIDs A WHERE A.Name = 'CandidateQuickNote')
DECLARE @ContactActionID uniqueidentifier = (SELECT A.ID FROM uvw_Action_NamesAndIDs A WHERE A.Name = 'ContactQuickNote')

WHILE @Min <= @Max
BEGIN
	BEGIN TRAN
		SET @BeginningTime = GETUTCDATE()

		IF @UpdateCandidates = 1
		BEGIN
			
			PRINT ''
			PRINT '..inserting note from phone number into ActionNote for candidates'
			INSERT INTO ActionNote(Notes)
			SELECT
				CU.Note
			FROM
				#CandidatesToUpdate CU
			WHERE
				CU.RowNumber = @Min
		
			DECLARE @ActionNoteIDForCandidate int = SCOPE_IDENTITY()
			
			PRINT ''
			PRINT '..inserting into ActionDetail for candidates'
			INSERT INTO ActionDetail(CandidateID, ActionID, CreatedDate, UpdatedDate, PerformedDate, PerformedPortal, PerformedActionPage, WebSiteID, DataNodeID, ActionNoteID, UniqueID)
			SELECT
				CU.CandidateID AS CandidateID
				,@CandidateActionID AS ActionID
				,@BeginningTime AS CreatedDate
				,@BeginningTime AS UpdatedDate
				,@BeginningTime AS PerformedDate
				,'Recruiter' AS PerformedPortal
				,'Candidate' AS PerformedPage
				,@WebSiteID AS WebSiteID
				,@DataNodeID AS DataNodeID
				,@ActionNoteIDForCandidate AS ActionNoteID
				,NEWID() AS UniqueID
			FROM
				#CandidatesToUpdate CU
			WHERE
				CU.RowNumber = @Min
			
			PRINT ''
			PRINT '..update phone numbers for candidates'
			UPDATE
				C
			SET
				C.PhoneMobile = CU.TidyMobileNumber
			FROM
				#CandidatesToUpdate CU
				INNER JOIN Candidate C ON C.ID = CU.CandidateID
			WHERE
				CU.RowNumber = @Min
		END

		IF @UpdateContacts = 1
		BEGIN
			
			PRINT ''
			PRINT '..inserting note from phone number into ActionNote for contacts'
			INSERT INTO ActionNote(Notes)
			SELECT
				CU.Note
			FROM
				#ContactsToUpdate CU
			WHERE
				CU.RowNumber = @Min
		
			DECLARE @ActionNoteIDForContact int = SCOPE_IDENTITY()
			
			PRINT ''
			PRINT '..inserting into ActionDetail for contacts'
			INSERT INTO ActionDetail(CandidateID, ActionID, CreatedDate, UpdatedDate, PerformedDate, PerformedPortal, PerformedActionPage, WebSiteID, DataNodeID, ActionNoteID, UniqueID)
			SELECT
				CU.ContactID AS CandidateID
				,@ContactActionID AS ActionID
				,@BeginningTime AS CreatedDate
				,@BeginningTime AS UpdatedDate
				,@BeginningTime AS PerformedDate
				,'Recruiter' AS PerformedPortal
				,'Contact' AS PerformedPage
				,@WebSiteID AS WebSiteID
				,@DataNodeID AS DataNodeID
				,@ActionNoteIDForContact AS ActionNoteID
				,NEWID() AS UniqueID
			FROM
				#ContactsToUpdate CU
			WHERE
				CU.RowNumber = @Min
			
			PRINT ''
			PRINT '..update phone numbers for contacts'
			UPDATE
				P
			SET
				P.WorkMob = CU.TidyMobileNumber
			FROM
				#ContactsToUpdate CU
				INNER JOIN Person P ON P.ID = CU.ContactID
			WHERE
				CU.RowNumber = @Min
		END

	IF @IsTestMode = 1
	BEGIN 
		ROLLBACK TRAN;
		PRINT 'Transaction Rolled Back'
		PRINT ''
	END
	ELSE
	BEGIN
		COMMIT TRAN;
		PRINT 'Transaction Committed!'
		PRINT ''
	END

	DECLARE @Message varchar(MAX) = 'Finished at row - ' + CAST(@Min AS varchar(MAX)) + ' of ' + CAST(@Max AS varchar(MAX))
	RAISERROR(@Message, 1, 10) WITH NOWAIT

	SET @Min = @Min + 1

	SET @EndTime = GETUTCDATE()
	SET @Duration = DATEDIFF(ms,@BeginningTime,@EndTime)
	PRINT 'Duration of the transaction in milliseconds ' + CAST(@Duration AS Varchar(50))
END

DROP TABLE IF EXISTS #CandidatesToUpdate
DROP TABLE IF EXISTS #CandidatesToUpdate
DROP FUNCTION IF EXISTS [dbo].[udf_ExtractNumbersFromString]