-- Kayıt olurken kullanıcının zaten Google ile kayıtlı olup olmadığını kontrol etmek için fonksiyon
-- Bu fonksiyon "Security Definer" olarak çalışır, yani auth tablosuna erişimi vardır.
-- Edge Function veya Client üzerinden çağrılabilir.

CREATE OR REPLACE FUNCTION public.check_user_provider(email_input text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  provider_type text;
BEGIN
  -- Check specifically for 'google' provider first
  SELECT provider INTO provider_type
  FROM auth.identities
  WHERE identity_data->>'email' = email_input
  AND provider = 'google'
  LIMIT 1;

  IF provider_type IS NOT NULL THEN
    RETURN 'google';
  END IF;

  -- Check if any other provider exists (e.g. email)
  SELECT provider INTO provider_type
  FROM auth.identities
  WHERE identity_data->>'email' = email_input
  LIMIT 1;

  RETURN provider_type; -- Returns null if not found
END;
$$;
