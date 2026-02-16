<?php

use Illuminate\Support\Facades\Route;
use Kreait\Firebase\Factory;

Route::get('/firebase-ping', function () {
    try {
        // Initialize Firebase
        $factory = (new Factory)->withServiceAccount(storage_path('firebase_credentials.json'));

        $auth = $factory->createAuth();
        $firestore = $factory->createFirestore();
        $storage = $factory->createStorage();

        // --- Firestore Ping ---
        $firestoreDb = $firestore->database();
        $collections = $firestoreDb->collections(); // just list collections
        $firestorePing = count($collections) >= 0 ? 'Firestore reachable' : 'Firestore unreachable';

        // --- Auth Ping ---
        $users = $auth->listUsers(['maxResults' => 1]); // just try fetching one user
        $authPing = $users ? 'Auth reachable' : 'Auth unreachable';

        // --- Storage Ping ---
        $bucket = $storage->getBucket();
        $storagePing = $bucket ? 'Storage reachable' : 'Storage unreachable';

        return response()->json([
            'firestore' => $firestorePing,
            'auth' => $authPing,
            'storage' => $storagePing
        ]);

    } catch (\Throwable $e) {
        return response()->json([
            'error' => $e->getMessage()
        ]);
    }
});



Route::get('/', function () {
    return view('welcome');
});
