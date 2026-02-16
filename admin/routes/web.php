<?php

use Illuminate\Support\Facades\Route;
use App\Services\FirebaseService;

Route::get('/test-firebase', function () {
    $firebase = new FirebaseService();

    $firestore = $firebase->getFirestore();
    $auth = $firebase->getAuth();
    $storage = $firebase->getStorage();

    // Example: list Firestore collections
    $collections = $firestore->collections();

    return response()->json([
        'collections' => array_map(fn($c) => $c->id(), $collections)
    ]);
});


Route::get('/', function () {
    return view('welcome');
});
