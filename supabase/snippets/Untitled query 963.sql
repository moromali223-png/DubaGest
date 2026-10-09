DO $$
DECLARE
  v_user_id uuid;
BEGIN
  -- 1. Vérifier si l'utilisateur existe déjà
  SELECT id INTO v_user_id FROM auth.users WHERE email = 'moro1@gmail.com';

  IF v_user_id IS NOT NULL THEN
    -- Mise à jour du mot de passe si le compte existe
    UPDATE auth.users
    SET encrypted_password = extensions.crypt('m12345678', extensions.gen_salt('bf')),
        email_confirmed_at = COALESCE(email_confirmed_at, now()),
        updated_at = now()
    WHERE id = v_user_id;

  ELSE
    -- Création du compte si inexistant
    v_user_id := gen_random_uuid();

    INSERT INTO auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change,
      email_change_token_current, phone_change, phone_change_token, reauthentication_token
    )
    VALUES (
      '00000000-0000-0000-0000-000000000000',
      v_user_id,
      'authenticated',
      'authenticated',
      'moro1@gmail.com',
      extensions.crypt('m12345678', extensions.gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"nom_complet":"Moro"}'::jsonb,
      now(),
      now(),
      '', '', '', '', '', '', '', ''
    );

    -- 2. Création de l'identité associée pour l'authentification email
    INSERT INTO auth.identities (
      id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
    )
    VALUES (
      gen_random_uuid(),
      v_user_id,
      v_user_id::text,
      jsonb_build_object('sub', v_user_id::text, 'email', 'moro1@gmail.com', 'email_verified', true),
      'email',
      now(),
      now(),
      now()
    );

  END IF;
END $$;
