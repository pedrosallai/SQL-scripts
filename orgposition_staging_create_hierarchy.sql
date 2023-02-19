--An example of the way I handled creating a hierarchy of all positions at the organisation.
--Creates a hierarchy utilising the DisplayLevel column. Principal of the organisation is level 1.

DECLARE @parent_level int
DECLARE @child_level int
SET @parent_level = 1
SET @child_level = 2
WHILE 	(
			select COUNT(positioncode) 
			from HRStaging.dbo.org_position_t1_import_new 
			where positioncode IN 
				(
					select ParentPositionCode 
					from HRStaging.dbo.org_position_t1_import_new
				) 
				AND DisplayLevel = @parent_level
		) > 0 --run this script until there's no positions left at the 'parent_level' which gets incremented
BEGIN --start at 'parent_level' which is 1 and gets incremented after every iteration
	UPDATE 
		HRStaging.dbo.org_position_t1_import_new
	SET 
		DisplayLevel = @child_level --set DisplayLevel to 'child_level' which is 2 and gets incremented
									--Displaylevel column is the hierarchy level
	WHERE 
		PositionCode IN 
		(
			SELECT 
				PositionCode 
			FROM 
				HRStaging.dbo.org_position_t1_import_new
			WHERE 
				ParentPositionCode IN --**if parent_level = 1, set DisplayLevel to 2 where the ParentPositionCode column of **
									  --**the particular Position record contains a PositionCode with the DisplayLevel of 1 **
				(
					SELECT 
						PositionCode 
					FROM 
						HRStaging.dbo.org_position_t1_import_new
					WHERE 
						DisplayLevel = @parent_level
				)
		)
	SET @parent_level = @parent_level + 1
	SET @child_level = @child_level + 1
END