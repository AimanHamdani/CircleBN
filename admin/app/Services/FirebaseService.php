<?php

namespace App\Services;

use Kreait\Firebase\Factory;
use Kreait\Firebase\Auth;
use Google\Cloud\Firestore\FirestoreClient;
use Kreait\Firebase\Firestore;

class FirebaseService
{
    protected Firestore $firestore;
    protected Auth $auth;
    protected $storage;

    public function __construct()
    {
   
        $factory = (new Factory)
            ->withServiceAccount(base_path('firebase_credentials.json'));

        $this->firestore = $factory->createFirestore()->database();

        $this->auth = $factory->createAuth();

        $this->storage = $factory->createStorage();
    }

    public function getFirestore(): FirestoreClient
    {
        return $this->firestore;
    }

    public function getAuth(): Auth
    {
        return $this->auth;
    }

    public function getStorage()
    {
        return $this->storage;
    }
}
