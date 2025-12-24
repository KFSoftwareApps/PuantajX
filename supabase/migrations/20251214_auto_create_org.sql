-- Trigger: Boş Org Kontrolü ve Otomatik Oluşturma
CREATE OR REPLACE FUNCTION public.handle_new_user_org()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_org_name text;
  v_org_code text;
BEGIN
  -- 1. İsim yoksa 'DEFAULT' yap
  v_org_name := COALESCE(new.raw_user_meta_data->>'org_name', 'DEFAULT');

  -- 2. Kod üret (İsimden slugify yap)
  v_org_code := COALESCE(
    new.raw_user_meta_data->>'org_code', 
    UPPER(REGEXP_REPLACE(v_org_name, '[^a-zA-Z0-9]', '', 'g'))
  );

  -- 3. Kod boşsa veya DEFAULT ise benzersiz yap
  IF v_org_code IS NULL OR v_org_code = '' OR v_org_code = 'DEFAULT' THEN
    v_org_code := 'DEFAULT_' || SUBSTRING(new.id::text, 1, 8);
  END IF;

  -- 4. Oluştur
  INSERT INTO public.organizations (id, code, name, plan, created_at, updated_at)
  VALUES (gen_random_uuid(), v_org_code, v_org_name, 'Free', NOW(), NOW())
  ON CONFLICT (code) DO NOTHING;

  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created_org ON auth.users;
CREATE TRIGGER on_auth_user_created_org
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_org();

-- RPC: Organizasyon Güncelleme (Setup Ekranı İçin - AKILLI ve ONARICI VERSİYON)
CREATE OR REPLACE FUNCTION update_own_organization(new_name text, new_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_old_code text;
  v_default_code_guess text;
  v_existing_target_id uuid;
  v_org_id uuid;
BEGIN
  v_user_id := auth.uid();
  
  -- 1. Kullanıcının eski kodunu bul
  v_old_code := auth.jwt()->'user_metadata'->>'org_code';
  v_default_code_guess := 'DEFAULT_' || SUBSTRING(v_user_id::text, 1, 8);
  
  IF v_old_code IS NULL OR v_old_code = '' OR v_old_code = 'DEFAULT' THEN
     v_old_code := v_default_code_guess;
  END IF;

  -- 2. Hedef kod (new_code) ZATEN VAR MI? (Daha önceki denemelerden kalmış olabilir)
  SELECT id INTO v_existing_target_id FROM public.organizations WHERE code = new_code LIMIT 1;
  
  IF v_existing_target_id IS NOT NULL THEN
    -- Hedef zaten var! O zaman eski (DEFAULT) kaydı sil, çünkü artık ona ihtiyacımız yok.
    -- Kullanıcı yeni kaydı sahiplenecek.
    DELETE FROM public.organizations WHERE code = v_old_code;
    
    -- Var olan yeni kaydı kullan
    v_org_id := v_existing_target_id;
    
    -- İsim güncellemek istersek:
    UPDATE public.organizations SET name = new_name, updated_at = NOW() WHERE id = v_org_id;
    
  ELSE
    -- Hedef yok, temiz güncelleme yap
    UPDATE public.organizations
    SET 
      name = new_name,
      code = new_code,
      updated_at = NOW()
    WHERE code = v_old_code
    RETURNING id INTO v_org_id;
  END IF;

  IF v_org_id IS NULL THEN
     -- Belki de v_old_code hiç oluşmadı? Veya çoktan silindi?
     -- Bu durumda güvenlik ağı olarak yeni bir insert yapabiliriz veya hata dönebiliriz.
     -- Hata dönelim ki Client fallback'e düşsün.
    RAISE EXCEPTION 'Organizasyon güncellenemedi veya taşınamadı. (Eski: %, Hedef: %)', v_old_code, new_code;
  END IF;
  
  RETURN json_build_object('status', 'success', 'id', v_org_id);
END;
$$;
