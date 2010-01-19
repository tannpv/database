
CREATE OR REPLACE FUNCTION applyCashReceiptLineBalance(INTEGER, INTEGER, NUMERIC, INTEGER) RETURNS NUMERIC AS $$
DECLARE
  pCashrcptId ALIAS FOR $1;
  pAropenid ALIAS FOR $2;
  pAmount ALIAS FOR $3;
  pCurrId ALIAS FOR $4;
  _balance NUMERIC;
  _amount NUMERIC;
  _applyAmount NUMERIC;
  _discount NUMERIC;
  _r RECORD;

BEGIN

--  All calculation performed in currency of Cash Receipt

--  Clear previously applied
  DELETE FROM cashrcptitem WHERE ((cashrcptitem_cashrcpt_id=pCashrcptId) AND (cashrcptitem_aropen_id=pAropenId));

--  Find the balance to apply
  SELECT (pAmount - (COALESCE(SUM(cashrcptitem_amount), 0) + COALESCE(SUM(cashrcptitem_discount), 0)) )INTO _amount
  FROM cashrcpt LEFT OUTER JOIN cashrcptitem ON (cashrcptitem_cashrcpt_id = cashrcpt_id)
  WHERE (cashrcpt_id=pCashrcptid)
  GROUP BY cashrcpt_curr_id, cashrcpt_distdate;

  SELECT (_amount - COALESCE(SUM(cashrcptmisc_amount), 0)) INTO _amount
  FROM cashrcptmisc
  WHERE (cashrcptmisc_cashrcpt_id=pCashrcptid);

-- RAISE NOTICE 'Amount (%)', _amount;

  IF (_amount = 0) THEN
    RETURN 0;
  END IF;

--  Determine Line balance
        SELECT currToCurr(aropen_curr_id, cashrcpt_curr_id,
               aropen_amount - aropen_paid, aropen_docdate) -
               COALESCE((SELECT (SUM(cashrcptitem_amount) + SUM(cashrcptitem_discount))
                           FROM cashrcptitem, cashrcpt
                           WHERE ((cashrcpt_id=cashrcptitem_cashrcpt_id)
                             AND  (NOT cashrcpt_void)
                             AND  (NOT cashrcpt_posted)
                             AND  (cashrcpt_id != pCashrcptId)
                             AND  (cashrcptitem_aropen_id=pAropenId))), 0) INTO _balance
            FROM aropen, cashrcpt
            WHERE ((aropen_id=pAropenId)
            AND (cashrcpt_id=pCashrcptId));

--  Determine Discount as per Terms
        SELECT  noNeg(least(_amount,_balance) * 
              CASE WHEN (CURRENT_DATE <= (aropen_docdate + terms_discdays)) THEN terms_discprcnt 
              ELSE 0.00 END - applied) INTO _discount
              FROM aropen LEFT OUTER JOIN terms ON (aropen_terms_id=terms_id), 
                   (SELECT COALESCE(SUM(arapply_applied), 0.00) AS applied  
		            FROM arapply, aropen 
                    WHERE ((arapply_target_aropen_id=pAropenId) 
                    AND (arapply_source_aropen_id=pAropenId) 
                    AND  (aropen_discount) )
                   ) AS data 
              WHERE (aropen_id=pAropenId) ;

--  Determine the amount to apply
    _applyAmount := least(_amount, _balance - _discount);

    IF (_applyAmount > 0) THEN
--  Create a new cashrcptitem
        INSERT INTO cashrcptitem
        ( cashrcptitem_aropen_id, cashrcptitem_cashrcpt_id,
          cashrcptitem_amount,cashrcptitem_discount )
        VALUES
        ( pAropenid, pCashrcptid, round(_applyAmount, 2), round(_discount, 2) );
    END IF;

  RETURN 1;

END;
$$ LANGUAGE 'plpgsql';

