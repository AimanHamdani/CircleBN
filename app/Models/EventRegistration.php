<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class EventRegistration extends Model
{
    use HasFactory;

    protected $fillable = [
        'event_id',
        'user_id',
        'amount',
        'gender',
        'age',
        'checked_in_at',
        'dropped_off',
        'qr_code',
        'emergency_contact',
        'tshirt_size',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'checked_in_at' => 'datetime',
            'dropped_off' => 'boolean',
        ];
    }

    public function event(): BelongsTo
    {
        return $this->belongsTo(Event::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
