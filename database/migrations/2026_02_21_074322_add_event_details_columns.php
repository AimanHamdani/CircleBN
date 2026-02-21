<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('events', function (Blueprint $table) {
            $table->string('location')->nullable()->after('description');
            $table->string('category')->nullable()->after('location');
            $table->string('image')->nullable()->after('category');
            $table->decimal('fee', 10, 2)->default(0)->after('capacity');
            $table->boolean('registration_open')->default(true)->after('fee');
        });

        Schema::table('event_registrations', function (Blueprint $table) {
            $table->string('qr_code')->nullable()->unique()->after('dropped_off');
            $table->string('emergency_contact')->nullable()->after('qr_code');
            $table->string('tshirt_size')->nullable()->after('emergency_contact');
        });
    }

    public function down(): void
    {
        Schema::table('events', function (Blueprint $table) {
            $table->dropColumn(['location', 'category', 'image', 'fee', 'registration_open']);
        });

        Schema::table('event_registrations', function (Blueprint $table) {
            $table->dropColumn(['qr_code', 'emergency_contact', 'tshirt_size']);
        });
    }
};
