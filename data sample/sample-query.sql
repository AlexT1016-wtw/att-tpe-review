SELECT *
FROM att_atttestplanexecution
WHERE att_atttestplanexecutionid = 'bc936de7-6444-f111-88b4-6045bdef4434'

SELECT *
FROM att_atttcexecution
WHERE att_testplanexecutionreference = 'bc936de7-6444-f111-88b4-6045bdef4434'

SELECT *
FROM att_testcasedetails
WHERE att_testcase = 'ae407551-6444-f111-88b3-7c1e52813c79'

SELECT * FROM att_atttestcase
WHERE att_atttestcaseid IN (SELECT att_testcaseid
FROM att_atttcexecution
WHERE att_testplanexecutionreference = 'bc936de7-6444-f111-88b4-6045bdef4434')
