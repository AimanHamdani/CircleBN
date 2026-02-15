<?php

use Illuminate\Support\Facades\Route;
use App\Services\FirebaseService;

Route::get('/test-firestore', function (FirebaseService $firebase) {
    $collection = $firebase->getFirestore()->collection('test');
    $collection->add([
        'message' => 'Hello Firebase!',
        'time' => now()->toDateTimeString(),
    ]);
    return 'Successfully connected to Firebase!';
});


Route::get('/', function () {
    return view('welcome');
});
