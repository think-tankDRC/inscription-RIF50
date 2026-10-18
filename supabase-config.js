(function () {
  'use strict';

  // À remplacer uniquement avec les identifiants de votre NOUVEAU projet Supabase.
  const SUPABASE_URL = 'https://almotqpqdzncqztopgrh.supabase.co';
  const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_nSAUyY4x6tYWzCSbk7WPzw_Gq4F3euz';

  if (!window.supabase) {
    console.error('La bibliothèque Supabase n’est pas chargée.');
    return;
  }

  if (!SUPABASE_URL || !SUPABASE_PUBLISHABLE_KEY) {
    console.info('Supabase n’est pas encore configuré pour ce projet.');
    return;
  }

  window.rifSupabase = window.supabase.createClient(
    SUPABASE_URL,
    SUPABASE_PUBLISHABLE_KEY
  );
})();
