<?php

namespace App\Services;


use Kreait\Firebase\Factory;

class FirebaseService
{
    protected $firestore;

    public function __construct()
    {
        $factory = (new Factory)
            ->withServiceAccount(base_path('firebase_credentials.json'));

        $this->firestore = $factory->createFirestore()->database();
    }

    public function getFirestore()
    {
        return $this->firestore;
    }
}
