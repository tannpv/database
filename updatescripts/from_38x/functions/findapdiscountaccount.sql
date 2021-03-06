CREATE OR REPLACE FUNCTION findAPDiscountAccount(INTEGER) RETURNS INTEGER AS $$
-- Copyright (c) 1999-2012 by OpenMFG LLC, d/b/a xTuple. 
-- See www.xtuple.com/CPAL for the full text of the software license.
DECLARE
  pVendid ALIAS FOR $1;
  _accntid INTEGER;

BEGIN

--  Check for a Vendor Type specific Account
  SELECT apaccnt_discount_accnt_id INTO _accntid
  FROM apaccnt, vend
  WHERE ( (apaccnt_vendtype_id=vend_vendtype_id)
   AND (vend_id=pVendid) );
  IF (FOUND) THEN
    RETURN _accntid;
  END IF;

--  Check for a Vendor Type pattern
  SELECT apaccnt_discount_accnt_id INTO _accntid
  FROM apaccnt, vend, vendtype
  WHERE ( (vendtype_code ~ apaccnt_vendtype)
   AND (vend_vendtype_id=vendtype_id)
   AND (apaccnt_vendtype_id=-1)
   AND (vend_id=pVendid) );
  IF (FOUND) THEN
    RETURN _accntid;
  END IF;

  RETURN -1;

END;
$$ LANGUAGE 'plpgsql';
