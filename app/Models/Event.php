<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Event extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'title',
        'description',
        'location',
        'category',
        'image',
        'status',
        'registration_deadline',
        'starts_at',
        'ends_at',
        'capacity',
        'fee',
        'registration_open',
    ];

    protected function casts(): array
    {
        return [
            'registration_deadline' => 'date',
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'fee' => 'decimal:2',
            'registration_open' => 'boolean',
        ];
    }

    public function isRegistrationOpen(): bool
    {
        if (! $this->registration_open) {
            return false;
        }

        if ($this->registration_deadline && $this->registration_deadline->isPast()) {
            return false;
        }

        return true;
    }

    public function isFull(): bool
    {
        if (! $this->capacity) {
            return false;
        }

        return $this->registrations()->count() >= $this->capacity;
    }

    public function spotsRemaining(): ?int
    {
        if (! $this->capacity) {
            return null;
        }

        return max(0, $this->capacity - $this->registrations()->count());
    }

    public function organizer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function registrations(): HasMany
    {
        return $this->hasMany(EventRegistration::class);
    }

    public function reviews(): HasMany
    {
        return $this->hasMany(EventReview::class);
    }

    public function announcements(): HasMany
    {
        return $this->hasMany(EventAnnouncement::class);
    }
}
