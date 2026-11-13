<?php
// Réglages du courrier des lecteurs. Le workflow « Mise en ligne sur iomino.fr » écrit config.php
// à partir du secret LIVRE_DOR_MOT_DE_PASSE ; ce fichier-ci sert de modèle et pour les essais.
return [
    // Empreinte du mot de passe de admin.php : php -r 'echo password_hash("...", PASSWORD_DEFAULT);'
    'empreinte_mot_de_passe' => '',
    // true : un message n'apparaît qu'après validation dans admin.php
    'moderation' => true,
];
